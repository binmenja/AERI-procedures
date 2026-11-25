#!/usr/bin/env python3
"""AERI Armory netCDF files -> GEOMS netCDF. Python version of processDailyAERIdata_GEOMS.m.

    from processDailyAERIdata_GEOMS import process_daily_aeri_geoms
    process_daily_aeri_geoms(root_dir, debug_temp=False, bias_vars=False)

or from a terminal:
    python processDailyAERIdata_GEOMS.py ROOT_DIR [--debug-temp] [--bias-vars]

Author: Benjamin Riot-Bretêcher, McGill University, 2026
Last modified: 2026-11-02
"""

import argparse
import datetime as dt
import glob
import os
import re
import warnings

import numpy as np
import netCDF4

MOPD = 1.03702765  # cm
FILL = np.float32(-9999.0)
FLAG_NAMES = [
    'abb_temp_outlier_flag', 'abb_thermistor_flag', 'air_interferometer_outlier_flag', 'bst_temp_outlier_flag',
    'cross_correlation_check', 'detector_check', 'detector_temp_check', 'hatch_flag', 'hbb_covariance_flag',
    'hbb_lw_nen_check', 'hbb_stable_flag', 'hbb_std_dev_flag', 'hbb_sw_nen_check', 'hbb_temp_outlier_flag',
    'hbb_thermistor_flag', 'hysteresis_check', 'imaginary_radiance_flag', 'lw_responsivity_flag',
    'missing_data_flag', 'safing_flag', 'sce_temp_deviation_check',
    'sky_brightness_temp_spectral_averages_ch1_flag', 'sky_brightness_temp_spectral_averages_ch2_flag',
    'spike_check', 'sw_responsivity_flag']
FLAG_MASKS = (2 ** np.arange(len(FLAG_NAMES))).astype(np.int32)  # CF flag_masks: 1, 2, 4, ... 2^24
DEBUG_VARS = {'airNearInterferometerTemp': 'Ambient air temperature near the interferometer',
              'interferometerWindowTemp': 'Interferometer window temperature measured on the outside of the '
                                          'aluminum window flange',
              'SCEtemp': 'Signal conditioning electronics inside air temperature'}
C1_TEMP_VARS = ['detectorTemp', 'motorDriverTemp', 'rackAmbientTemp', 'coolerExpanderTemp', 'coolerCompressorTemp',
                'mirrorMotorTemp', 'airNearBBsTemp', 'HBBbottomTemp', 'HBBapexTemp', 'HBBtopTemp', 'ABBbottomTemp',
                'ABBapexTemp', 'ABBtopTemp', 'NBBbottomTemp', 'NBBapexTemp', 'calibrationHBBtemp',
                'calibrationCBBtemp', 'calibrationAmbientTemp']
F1_VARS = ['BBsupportStructureTemp', 'sceneMirPosEncoder', 'ref1BlackbodyApexTemp', 'ref1BlackbodyBottomRimTemp']

# name, lat, lon, AERI serial; matched within 0.2 deg of the file position
SITES = [('gault', 45.54, -73.15, '125'), ('nrc', 45.45, -75.62, '122'), ('burnside', 45.5048, -73.5749, '124'),
         ('inuvik', 68.1832, -133.2840, '125'), ('radar', 45.4241, -73.9377, '122')]
# sites whose AERI configuration had wrong coordinates (the SSEC Madison ones): position from the folder name
SITE_FROM_PATH = {'ponex': ('125', 68 + 18 / 60 + 31.53 / 3600, -(133 + 28 / 60 + 40.32 / 3600), 60),
                  'gault': ('125', 45.53502, -73.14901, 132), 'burnside': ('124', 45.5048, -73.5749, 97)}
MADISON = (43.0706, -89.4072)
# EarthCARE (ECALOT / AOID39821): Ottawa-area sites, Sept 2024 to June 2025
EARTHCARE_LOCATION = {'NRC': 'OTTAWA.CYOW', 'GAULT': 'GAULT', 'BURNSIDE': 'BURNSIDE'}
EARTHCARE_PERIOD = (dt.datetime(2024, 9, 1), dt.datetime(2025, 6, 30, 23, 59, 59))


def read(path, *names):
    """Raw values (no masking), and time in POSIX seconds as 'time'."""
    with netCDF4.Dataset(path) as ds:
        ds.set_auto_maskandscale(False)
        out = {n: ds[n][:] for n in names if n in ds.variables}
        out['time'] = ds['time_offset'][:].astype(float) + float(ds['base_time'][:])
    return out


def match(t1, t2, tol=1.0):
    """Indices (i1, i2) pairing each t1 with its nearest t2 within tol seconds, each t2 used once."""
    order = np.argsort(t2)
    k = np.clip(np.searchsorted(t2[order], t1), 1, len(t2) - 1)
    near = np.where(np.abs(t2[order][k - 1] - t1) <= np.abs(t2[order][k] - t1), k - 1, k)
    i2 = order[near]
    ok = np.abs(t2[i2] - t1) <= tol
    i1, i2 = np.flatnonzero(ok), i2[ok]
    i2, first = np.unique(i2, return_index=True)
    return i1[first], i2


def planck(wnum, temp):
    """Radiance in mW / (m2 sr cm-1), shape (len(temp), len(wnum))."""
    return 1e3 * 1.191066e-8 * wnum ** 3 / np.expm1(1.438833 * wnum / temp[:, None])


def site(path, lat, lon, alt):
    """Location, serial, lat, lon, alt, and whether the position comes from the site table."""
    p = path.lower()
    if 'ponex' in p or (abs(lat - MADISON[0]) < 0.2 and abs(lon - MADISON[1]) < 0.2):
        for name, (serial, slat, slon, salt) in SITE_FROM_PATH.items():
            if name in p:
                warnings.warn(f'{path}: file position ({lat:.4f}, {lon:.4f}) replaced with the {name} site position')
                return name, serial, slat, slon, salt, True
    for name, slat, slon, serial in SITES:
        if abs(lat - slat) < 0.2 and abs(lon - slon) < 0.2:
            return name, serial, lat, lon, alt, False
    warnings.warn(f'{path}: unknown location ({lat:.4f}, {lon:.4f})')
    return f'unknown_{abs(lat):.4f}_{abs(lon):.4f}', 'UNK', lat, lon, alt, False


def iso(t):
    return dt.datetime.fromtimestamp(round(t), dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')


def var(data, description, notes=' ', units=' ', si=' ', valid=None, dims='T', dtype='f4', vname=None, **extra):
    """One output variable: data plus its GEOMS attributes. dims: 'T' time, 'TW' time x wavenumber,
    'W' wavenumber, '' scalar, or a string dimension name."""
    return dict(data=data, description=description, notes=notes, units=units, si=si, valid=valid, dims=dims,
                dtype=dtype, extra=extra)


def variables(d, have_qc, debug_temp, bias_vars):
    """All output variables, in file order. d holds the matched data of one day."""
    nt = len(d['time'])
    rad = 'mW m-2 sr-1 cm-1', '0.0;0.1;kg m-1 sr-1 s-3'
    deg = 'deg', '0.0;1.74533E-2;rad'
    v = {
        'DATETIME': var((d['time'] - 946684800) / 86400, 'Mean time of the measurement sequence used for each '
                        'retrieval; defined relative to reference datetime of Jan. 1 2000 at 0:00:00',
                        'Center of the scan (AERI summary file Time/timeHHMMSS: "Time at center of AERI sky '
                        'observation period"). Start/stop = DATETIME +/- INTEGRATION.TIME/2.', 'MJD2K',
                        '0.0;86400.0;s', 'minmax', dtype='f8'),
        'INTEGRATION.TIME': var(d['sceneViewDuration'], 'Scan duration', 'From sceneViewDuration in the AERI '
                                'summary file; varies scan to scan.', 's', '0.0;1.0;s', (0, 60)),
        'LATITUDE.INSTRUMENT': var(np.full(nt, d['lat']), 'Inst. geolocation. Latitude north (decimal degrees) of '
                                   'the location of the instrument (+ for north; - for south)', d['coord_note'],
                                   *deg, (-90, 90)),
        'LONGITUDE.INSTRUMENT': var(np.full(nt, d['lon']), 'Inst. geolocation. Longitude east (decimal degrees) of '
                                    'the location of the instrument (+ for east; - for west)', d['coord_note'],
                                    *deg, (-180, 180)),
        'ALTITUDE.INSTRUMENT': var(np.full(nt, d['alt']), 'Inst. geolocation. Altitude of the instrument relative '
                                   'to the location site', d['coord_note'], 'm', '0.0;1.0;m', (-500, 10000)),
        'WAVENUMBER': var(d['wnum'], 'Spectral wavenumber', ' ', 'cm-1', '0.0;1.0E2;m-1', 'minmax', dims='W'),
        'RADIANCE': var(d['rad'], 'Calibrated Atmospheric Radiance', 'Atmospheric infrared radiance spectra. Use '
                        'FLAG.MEASUREMENT.QUALITY to filter data based on quality control flags. Details about the '
                        'flags can be found at https://gitlab.ssec.wisc.edu/aeri/aeri_quality_control', *rad,
                        (-100, 1000), dims='TW'),
        'RADIANCE_NOISE.EQUIVALENT': var(d['nen'], 'Sky noise equivalent radiance (NESR)', 'SkyNENch1 values '
                                         'interpolated to match radiance wavenumbers', *rad, (0, 1000), dims='TW'),
        'RADIANCE_CALIBRATION.UNCERTAINTY': var(d['cal_error'], 'Absolute calibration error 1-sigma absolute '
                                                'calibration error for the radiance. Calculated based on ambient '
                                                'blackbody apex temperature.', '1-sigma absolute calibration error '
                                                'for the radiance. Calculated based on ambient blackbody apex '
                                                'temperature.', *rad, (0, 1000), dims='TW'),
        'RADIANCE_FOV': var(d['fov'], 'Measurement field-of-view', 'Full-angle zenith FOV = 2 x FFOVhalfAngle from '
                            'the AERI summary file.', 'mrad', '0.0;1.0E-3;rad', (0, 100), dims=''),
        'RESPONSIVITY_SPECTRAL': var(d['resp'], 'Responsivity spectral averages', 'ResponsivitySpectralAveragesCh1 '
                                     'interpolated to radiance wavenumbers, in counts per mW-1 m2 sr cm.',
                                     'mW-1 m2 sr cm', '0.0;10.0;s3 m sr kg-1', (0, 10000), dims='TW'),
        'FLAG.MEASUREMENT.QUALITY': var(d['flags'], 'Quality control bitmask flag',
                                        '0 = passed, 1 = failed for each test. Use flag_masks and flag_meanings to '
                                        'identify individual tests; user chooses which flags to apply.' if have_qc
                                        else 'Quality control not available for this day (AERI Armory '
                                        'quality_control failed); all values set to the fill value.',
                                        '1', '0;1;1', (0, int(FLAG_MASKS.sum())), dtype='i4',
                                        flag_masks=FLAG_MASKS, flag_meanings=' '.join(FLAG_NAMES)),
        'PATH.DIFFERENCE_MAXIMUM': var(MOPD, 'Maximum optical path difference', 'Full Width Half Maximum = '
                                       '1.2067/(2*Maximum Optical Path Difference). AERI Ideal Line Shape '
                                       'available upon request.', 'cm', '0.0;0.01;m', (0, 10), dims=''),
        'SURFACE.TEMPERATURE': var(d['outsideAirTemp'], 'Surface temperature', 'From outsideAirTemp, hatch opening, '
                                   'not a dedicated 2 m surface station. See SURFACE.TEMPERATURE_SOURCE.', 'K',
                                   '0.0;1.0;K', (173, 333)),
        'SURFACE.TEMPERATURE_SOURCE': var('AERI outsideAirTemp sensor, hatch opening, not a dedicated 2 m surface '
                                          'station.', 'Source of temperature measurement', valid='string'),
        'SURFACE.PRESSURE': var(d['atmosphericPressure'], 'Surface pressure', 'From atmosphericPressure, sensor '
                                'housed in the AERI electronics enclosure. See SURFACE.PRESSURE_SOURCE.', 'hPa',
                                '0.0;1.0E2;kg m-1 s-2', (500, 1100)),
        'SURFACE.PRESSURE_SOURCE': var('AERI atmosphericPressure sensor, housed in the instrument electronics '
                                       'enclosure.', 'Source of pressure measurement', valid='string'),
    }
    # engineering / bias variables: shorter attribute sets
    if debug_temp:
        for name, description in DEBUG_VARS.items():
            v[name] = var(d[name], description, units='degrees_Kelvin', valid='short')
    if bias_vars:
        v['sceneMirrorTemp'] = var(d['sceneMirrorTemp'], None, valid='name_only')
        v['interferometerEnclosureRelativeHumidity'] = var(
            d['interferometerEnclosureRelativeHumidity'], 'Relative humidity in the interferometer enclosure, from '
            'SUM file', None, '%', valid='short')
        v['coolerCurrent'] = var(d['coolerCurrent'], 'Stirling cycle cooler current, from SUM file', None, 'A',
                                 valid='short')
        for name in F1_VARS:
            v[name] = var(d[name], None, valid='name_only')
        for name in C1_TEMP_VARS:
            v[name] = var(d[name], f'{name} from AERI file', units='degrees_Kelvin', valid='short')
    return v


def global_attributes(location, data_location, serial, start, stop, var_names, filename, earthcare):
    address = '805 Sherbrooke St W Montreal;QC H3A 0B9;CANADA'
    owner = 'Benjamin Riot-Bretêcher;'
    g = {}
    if not earthcare:
        g.update(Conventions='GEOMS-1.0', title=f'AERI {location} processed data', source='AERI instrument',
                 history=f'Created on {dt.datetime.now():%Y-%m-%d %H:%M:%S}')
    for who, name, email in [('PI', 'Huang;Yi', 'yi.huang@mcgill.ca'),
                             ('DO', 'Riot-Bretecher;Benjamin', 'benjamin.riotbretecher@mail.mcgill.ca'),
                             ('DS', 'Riot-Bretecher;Benjamin', 'benjamin.riotbretecher@mail.mcgill.ca')]:
        g.update({f'{who}_NAME': name, f'{who}_AFFILIATION': 'McGill University;MCGILL',
                  f'{who}_ADDRESS': address, f'{who}_EMAIL': email})
    g.update(DATA_DESCRIPTION=f'Processed AERI radiance data from {location}',
             DATA_DISCIPLINE='ATMOSPHERIC.PHYSICS;INSITU;GROUNDBASED', DATA_GROUP='EXPERIMENTAL;SCALAR.STATIONARY',
             DATA_LOCATION=data_location, DATA_SOURCE=f'AERI_MCGILL{serial}', DATA_VARIABLES=';'.join(var_names),
             DATA_START_DATE=start, DATA_STOP_DATE=stop, DATA_FILE_VERSION='001', DATA_MODIFICATIONS='Version 001',
             DATA_CAVEATS='Unknown',
             DATA_RULES_OF_USE='Follows the EVDC EarthCARE data protocol at https://earthcare-protocol.evdc.nilu.no/'
             if earthcare else 'Unknown',
             DATA_ACKNOWLEDGEMENT=' ',
             DATA_QUALITY='Quality-controlled using multiple flags from AERI Armory; see FLAG.MEASUREMENT.QUALITY',
             DATA_TEMPLATE='GEOMS-TE-AERI-001', DATA_PROCESSOR=' ', FILE_NAME=filename,
             FILE_GENERATION_DATE=f'{dt.datetime.now(dt.timezone.utc):%Y%m%dT%H%M%SZ}',
             FILE_ACCESS='EARTHCARE' if earthcare else owner,
             FILE_PROJECT_ID='AOID39821' if earthcare else 'Unknown', FILE_DOI=' ',
             FILE_ASSOCIATION='EARTHCARE' if earthcare else owner,
             FILE_META_VERSION='04R114;CUSTOM' if earthcare else '04R001;IDLCR8HDF')
    return g


def write_geoms(path, v, globals_):
    nt, nw = v['RADIANCE']['data'].shape
    with netCDF4.Dataset(path, 'w', format='NETCDF4') as ds:
        ds.set_auto_maskandscale(False)
        ds.createDimension('DATETIME', nt)
        ds.createDimension('WAVENUMBER', nw)
        dims = {'T': ('DATETIME',), 'TW': ('DATETIME', 'WAVENUMBER'), 'W': ('WAVENUMBER',), '': ()}
        sizes = {'T': f'{nt}', 'TW': f'{nt};{nw}', 'W': f'{nw}', '': '1'}
        for name, s in v.items():
            if s['valid'] == 'string':  # character variable with its own STRING_n dimension
                n = len(s['data'])
                ds.createDimension(f'STRING_{n}', n)
                x = ds.createVariable(name, 'S1', (f'STRING_{n}',))
                x[:] = np.array(list(s['data']), dtype='S1')
                atts = dict(VAR_NAME=name, VAR_DESCRIPTION=s['description'], VAR_NOTES=' ', VAR_SIZE='1',
                            VAR_DEPEND='CONSTANT', VAR_DATA_TYPE='STRING', VAR_UNITS=' ', VAR_SI_CONVERSION=' ',
                            VAR_VALID_MIN=' ', VAR_VALID_MAX=' ', VAR_FILL_VALUE=' ')
            else:
                x = ds.createVariable(name, s['dtype'], dims[s['dims']])
                x[...] = np.asarray(s['data']).astype(s['dtype'])
                atts = dict(VAR_NAME=name)
                if s['valid'] != 'name_only':
                    atts.update(VAR_DESCRIPTION=s['description'], VAR_NOTES=s['notes'],
                                VAR_SIZE=sizes[s['dims']], VAR_DEPEND={'': 'CONSTANT', 'TW': 'DATETIME;WAVENUMBER',
                                                                       'W': 'WAVENUMBER'}.get(s['dims'], 'DATETIME'),
                                VAR_DATA_TYPE={'f8': 'DOUBLE', 'i4': 'INTEGER'}.get(s['dtype'], 'REAL'),
                                VAR_UNITS=s['units'])
                    if s['notes'] is None:
                        del atts['VAR_NOTES']
                if s['valid'] not in ('name_only', 'short'):
                    atts['VAR_SI_CONVERSION'] = s['si']
                    t = np.dtype(s['dtype']).type
                    lo, hi = ((np.min(s['data']), np.max(s['data'])) if s['valid'] == 'minmax' else s['valid'])
                    atts.update(VAR_VALID_MIN=t(lo), VAR_VALID_MAX=t(hi), VAR_FILL_VALUE=t(-1 if s['dtype'] == 'i4'
                                                                                             else -9999))
                atts.update(s['extra'])
            x.setncatts(atts)
        ds.setncatts(globals_)


def process_day(c1_file, debug_temp=False, bias_vars=False):
    ae_dir = os.path.dirname(os.path.dirname(c1_file))  # inputs are looked up in the same AE folder
    date = re.findall(r'\d+', os.path.basename(c1_file))[0]

    def find(pattern):
        hits = sorted(glob.glob(os.path.join(ae_dir, '*', pattern)))
        return hits[0] if hits else None

    sum_file, qc_file = find(f'*{date}_sum*.nc'), find(f'*{"20" * (len(date) == 6)}{date}QC*.nc')
    f1_file = find(f'*{date}F1*.nc') if bias_vars else None
    if sum_file is None:
        warnings.warn(f'{c1_file}: no summary file, skipped')
        return

    c1 = read(c1_file, 'mean_rad', 'wnum1', 'Latitude', 'Longitude', 'Altitude', *C1_TEMP_VARS)
    sm = read(sum_file, 'SkyNENch1', 'ResponsivitySpectralAveragesCh1', 'ABBapexTemp', 'wnum1', 'sceneViewDuration',
              'FFOVhalfAngle', 'outsideAirTemp', 'atmosphericPressure', 'sceneMirrorTemp',
              'interferometerEnclosureRelativeHumidity', 'coolerCurrent', *DEBUG_VARS)
    qc = read(qc_file, *FLAG_NAMES) if qc_file else {'time': sm['time']}
    if qc_file is None:
        warnings.warn(f'{c1_file}: no QC file, FLAG.MEASUREMENT.QUALITY set to the fill value')

    # match QC to SUM, then C1 to the matched QC times (within 1 s)
    iq, isum = match(qc['time'], sm['time'])
    ic, k = match(c1['time'], qc['time'][iq])
    iq, isum = iq[k], isum[k]
    if len(ic) == 0:
        warnings.warn(f'{c1_file}: no matching times between C1, SUM and QC, skipped')
        return

    lat, lon, alt = (float(c1[n][0]) if n in c1 else np.nan for n in ('Latitude', 'Longitude', 'Altitude'))
    location, serial, lat, lon, alt, from_site = site(c1_file, lat, lon, alt)
    wnum = c1['wnum1']
    d = dict(time=c1['time'][ic], wnum=wnum, rad=c1['mean_rad'][ic], lat=lat, lon=lon, alt=alt,
             coord_note='Stationary instrument; constant across DATETIME.' + (
                 ' Surveyed site position (the AERI configuration had wrong coordinates).' if from_site else ''),
             fov=sm['FFOVhalfAngle'][isum][0] * 2000,
             nen=np.array([np.interp(wnum, sm['wnum1'], row) for row in sm['SkyNENch1'][isum]]),
             resp=np.array([np.interp(wnum, sm['wnum1'], row) for row in sm['ResponsivitySpectralAveragesCh1'][isum]]),
             cal_error=0.01 * planck(wnum.astype(float), sm['ABBapexTemp'][isum].astype(float)) / 3)  # 1% = 3 sigma
    for n in ['sceneViewDuration', 'outsideAirTemp', 'atmosphericPressure', 'sceneMirrorTemp',
              'interferometerEnclosureRelativeHumidity', 'coolerCurrent', *DEBUG_VARS]:
        d[n] = sm[n][isum] if n in sm else None
    for n in C1_TEMP_VARS:
        d[n] = c1[n][ic] if n in c1 else np.full(len(ic), np.nan)

    if qc_file:
        bits = np.array([qc[n][iq] > 0 if n in qc else np.zeros(len(iq), bool) for n in FLAG_NAMES])
        d['flags'] = FLAG_MASKS @ bits.astype(np.int32)
    else:
        d['flags'] = np.full(len(ic), -1)

    # F1 values at the nearest F1 record within 60 s (ref1 variables have 3 values per record: first is used)
    for n in F1_VARS:
        d[n] = np.full(len(ic), np.nan)
    if f1_file:
        f1 = read(f1_file, *F1_VARS)
        j = np.array([np.nanargmin(np.abs(f1['time'] - t)) for t in d['time']])
        ok = np.abs(f1['time'][j] - d['time']) <= 60
        for n in F1_VARS:
            x = f1[n] if f1[n].ndim == 1 else f1[n][:, 0]
            d[n][ok] = x[j[ok]]

    # file name and EarthCARE metadata
    start, stop = iso(d['time'][0]), iso(d['time'][-1])
    location = location.upper()
    start_dt = dt.datetime.fromtimestamp(d['time'][0], dt.timezone.utc).replace(tzinfo=None)
    earthcare = location in EARTHCARE_LOCATION and EARTHCARE_PERIOD[0] <= start_dt <= EARTHCARE_PERIOD[1]
    data_location = EARTHCARE_LOCATION[location] if earthcare else location
    filename = f'groundbased_aeri_mcgill{serial}_{data_location.lower()}_{start.lower()}_{stop.lower()}_001.nc'
    out_dir = os.path.join(ae_dir, 'output')
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, filename)
    if os.path.exists(path):
        os.remove(path)

    v = variables(d, qc_file is not None, debug_temp or bias_vars, bias_vars)
    write_geoms(path, v, global_attributes(location, data_location, serial, start, stop, list(v), filename,
                                           earthcare))
    print(f'{location} {start}: {len(ic)} spectra -> {path}')


def process_daily_aeri_geoms(root_dir, debug_temp=False, bias_vars=False):
    """Write one GEOMS file per *C1_rnc.nc found under root_dir (same as processDailyAERIdata_GEOMS.m).

    root_dir   folder searched recursively for *C1_rnc.nc files
    debug_temp add engineering temperatures
    bias_vars  add bias variables (implies debug_temp)
    """
    for c1_file in sorted(glob.glob(os.path.join(root_dir, '**', '*C1_rnc.nc'), recursive=True)):
        try:
            process_day(c1_file, debug_temp, bias_vars)
        except Exception as err:
            warnings.warn(f'{c1_file}: {err!r}')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument('root_dir', help='folder searched recursively for *C1_rnc.nc files')
    p.add_argument('--debug-temp', action='store_true', help='add engineering temperatures')
    p.add_argument('--bias-vars', action='store_true', help='add bias variables (implies --debug-temp)')
    a = p.parse_args()
    process_daily_aeri_geoms(a.root_dir, a.debug_temp, a.bias_vars)
