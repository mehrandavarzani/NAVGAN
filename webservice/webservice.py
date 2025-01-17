from flask import Flask,request,abort
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy.sql import text
import psycopg2
from datetime import datetime,timedelta
from collections import namedtuple
import json
import logging
from logging.handlers import RotatingFileHandler
import os

PSQL_USER = 'navgan'
PSQL_PASS = 'navgan'

MYSQL_HOST = 'localhost'    # change this to freezeye host
MYSQL_USER = 'freezeye'
MYSQL_PASS = 'adminco'

MYSQL_BASE_URI = 'mysql+pymysql://{user}:{passwd}@{host}'.format(user=MYSQL_USER,passwd=MYSQL_PASS,host=MYSQL_HOST)

app = Flask(__name__)

app.config['SQLALCHEMY_BINDS'] = {
    'freezeye':        '{}/freezeye'.format(MYSQL_BASE_URI),
    'freezeye_data':   '{}/freezeye_data'.format(MYSQL_BASE_URI),
    'navgan':          'postgres://{user}:{passwd}@localhost/navgan'.format(user=PSQL_USER,passwd=PSQL_PASS)
}
#@TODO change pg dbname above
db = SQLAlchemy(app)

try:
    freezeye_eng = db.get_engine(app,'freezeye')
    freezeye_data_eng = db.get_engine(app,'freezeye_data')

except:
    app.logger.exception('Error during making connection to freezeye')
    abort(500)

try:
    navgan_eng = db.get_engine(app,'navgan')

except:
    app.logger.exception('Error during making connection to navgan')
    #abort(500)

app.debug = True    # Use False in production

# Log to file in production mode
if not app.debug:

    if not os.path.exists('logs'):
        os.mkdir('logs')

    file_handler = RotatingFileHandler('logs/webservice.log', maxBytes=10240,
                                       backupCount=10)

    file_handler.setFormatter(logging.Formatter(
        '%(asctime)s %(levelname)s: %(message)s [in %(pathname)s:%(lineno)d]'))

    file_handler.setLevel(logging.INFO)
    app.logger.addHandler(file_handler)

    app.logger.setLevel(logging.INFO)
    app.logger.info('Webservice startup')


one_day_td = timedelta(days=1)


def get_sensor_type(branch_id,room_id):
    """
    Identify sensor type (moving or fixed)
    :param branch_id: warehouse id
    :param room_id: room id
    :return  02 for fixed sensors and 01 for moving ones

    """
    query = text('''SELECT sensor_type FROM freezeye_data.sensor_branch
                WHERE branch_id=:bid AND sensor_id=:rid''')

    try:
        result_set = freezeye_data_eng.execute(query,bid=branch_id,rid=room_id)

    except:
        app.logger.exception('An error occurred while getting sensor_type')
        abort(500)

    rows = result_set.fetchall()

    if rows:
        return '02' if int(rows[0][0]) == 0 else '01'


def fixed_sensor_column_exists(table_name,sensor_id):
    """
    Check if table and sensor column exists
    :param table_name:
    :param sensor_id:
    :return: True if column exists else False
    """

    query = text("""SELECT EXISTS(SELECT 1 FROM information_schema.COLUMNS 
                WHERE TABLE_SCHEMA = 'freezeye_data'
                AND TABLE_NAME = :tbl_name 
                AND COLUMN_NAME = concat('S',:sid,'TM')) as is_exists""")

    try:
        result_set = freezeye_data_eng.execute(query,tbl_name=table_name,sid=sensor_id)

    except:

        app.logger.exception('An error occurred while checking columns')        
        #abort(500)

    rows = result_set.fetchall()
    return rows[0][0] == 1


def get_fixed_sensor_coordinates(room_id):
    """
    Get latitude and longitude of sensor
    :param room_id: room id of sensor
    :return: Namedtuple(LAT,LNG)
    """
    query = text("""SELECT LAT,LNG FROM freezeye.centers WHERE system_id=:rid""")

    try:
        result_set = freezeye_eng.execute(query,rid=room_id)

    except:
        app.logger.exception('An error occurred while getting coordinates')
        abort(500)

    Record = namedtuple('Record', result_set.keys())
    records = [Record(*r) for r in result_set.fetchall()]

    if records:
        return records[0]

    else:
        return Record(None,None)


def get_fixed_sensor_data(branch_id,room_id,sensor_id,start_date,end_date):
    """
    Get sensor data from freezeye data store and
    make an average every 15 minutes
    :param branch_id: warehouse id of sensor
    :param room_id: room id of sensor
    :param sensor_id: sensor number
    :param start_date: starting date of sampling
    :param end_date: end date of sampling
    :return: List of records with following columns
    {'branch_ID','room_id','sensor_id','sensor_Type','logDateTime',
     'LAT','LNG','T','Tmin','Tmax','H','Hmin','Hmax'}
    """

    result_data = []
    loop_date = start_date

    while loop_date <= end_date:
        date_string = loop_date.strftime('%Y_%m_%d')
        table_name = "t_{date_string}".format(date_string=date_string)
        if fixed_sensor_column_exists(table_name,sensor_id):
            coords = get_fixed_sensor_coordinates(room_id)
            t_field = 'S{sensor_id}TM'.format(sensor_id=sensor_id)
            h_field = 'S{sensor_id}HM'.format(sensor_id=sensor_id)
            query = text(
                '''SELECT _datetime as log_date_time,{t_field},{h_field} 
                FROM freezeye_data.{table_name} where ID=:rid'''.format(
                    t_field=t_field, h_field=h_field, table_name=table_name
                )
            )

            try:
                result = freezeye_data_eng.execute(query, rid=room_id)
            except:
                app.logger.exception('An error occurred while getting data')
                abort(500)

            Record = namedtuple('Record', result.keys())
            records = [Record(*r) for r in result.fetchall()]

            if records:

                start_rec = records[0]

                tmin = tmax = hmin = hmax = 'xx.x'

                tsum = hsum = None

                tcounter = 0
                hcounter = 0

                inserted = False

                for rec in records:

                    inserted = False

                    temperature = getattr(rec, t_field)
                    humidity = getattr(rec, h_field)
                    log_date_time = getattr(rec, 'log_date_time')

                    if -50 <= temperature <= 100:

                        if tsum is None:
                            tsum = temperature

                        else:
                            tsum = tsum + temperature

                        tcounter += 1
                    
                        if tmin == 'xx.x' or tmin > temperature:
                            tmin = temperature

                        if tmax == 'xx.x' or tmax < temperature:
                            tmax = temperature

                    if 0 <= humidity <= 100:
                       
                        if hsum is None:
                            hsum = humidity

                        else:
                            hsum = hsum + humidity

                        hcounter += 1

                        if hmin == 'xx.x' or hmin > humidity:
                            hmin = humidity

                        if hmax == 'xx.x' or hmax < humidity:
                            hmax = humidity

                    timediff = (log_date_time - start_rec.log_date_time).total_seconds()
                 
                    if timediff >= 900:

                        tavg = 'xx.x' if tcounter == 0 else round(tsum / tcounter * 100) / 100

                        havg = 'xx.x' if hcounter == 0 else round(hsum / hcounter * 100) / 100
                        
                        result_data.append({
                            'branch_id': branch_id,
                            'room_id': room_id,
                            'sensor_id': sensor_id,
                            'sensor_Type': '02',
                            'logDateTime': log_date_time.strftime('%Y-%m-%d %H:%M:%S'),
                            'LAT': coords.LAT,
                            'LNG': coords.LNG,
                            'T': tavg,
                            'Tmin': tmin,
                            'Tmax': tmax,
                            'H': havg,
                            'Hmin': hmin,
                            'Hmax': hmax,
                        })

                        inserted = True
                        start_rec = rec
                        hcounter = 0
                        tcounter = 0
                        tmin = tmax = hmin = hmax = 'xx.x'
                        tsum = hsum = None

                if not inserted:

                    tavg = 'xx.x' if tcounter == 0 else round(tsum / tcounter * 100) / 100

                    havg = 'xx.x' if hcounter == 0 else round(hsum / hcounter * 100) / 100
                        
                    result_data.append({
                        'branch_id': branch_id,
                        'room_id': room_id,
                        'sensor_id': sensor_id,
                        'sensor_Type': '02',
                        'logDateTime': log_date_time.strftime('%Y-%m-%d %H:%M:%S'),
                        'LAT': coords.LAT,
                        'LNG': coords.LNG,
                        'T': tavg,
                        'Tmin': tmin,
                        'Tmax': tmax,
                        'H': havg,
                        'Hmin': hmin,
                        'Hmax': hmax,
                    })

        loop_date += one_day_td

    return result_data


def get_moving_sensor_id(branch_id,room_id,sensor_id):

    query = text("""SELECT id FROM api.device_hardware
                    WHERE branch_id=:bid AND room_id=:rid AND device_id=:sid""")
    try:
        result_set = navgan_eng.execute(query,bid=branch_id,rid=room_id,sid=sensor_id)

    except:
        app.logger.exception('An error occurred while getting device_id')
        abort(500)

    rows = result_set.fetchall()

    if rows:
        return rows[0][0]


def get_moving_sensor_table_name(date):

    query = text("""SELECT table_name FROM data.tables WHERE created=:date""")

    try:
        result_set = navgan_eng.execute(query,date=date)

    except:
        app.logger.exception('An error occurred while getting table_name')
        abort(500)

    rows = result_set.fetchall()

    if rows:
        return rows[0][0]


def get_moving_sensor_data(branch_id,room_id,sensor_id,start_date,end_date):

    result_data = []
    loop_date = start_date

    while loop_date <= end_date:

        table_name = get_moving_sensor_table_name(loop_date)

        if table_name:

            device_id = get_moving_sensor_id(branch_id,room_id,sensor_id)
            query = text('''SELECT timestamp,temperature,
                             humidity,longitude,latitude
                             FROM data.{table_name} where device_id=:sid'''.format(table_name=table_name))

            try:
                result = navgan_eng.execute(query, sid=device_id)

            except:
                app.logger.exception('An error occurred while getting data')
                abort(500)

            Record = namedtuple('Record', result.keys())
            records = [Record(*r) for r in result.fetchall()]

            if records:

                start_rec = records[0]

                tmin = tmax = hmin = hmax = 'xx.x'
                tsum = hsum = None
                tcounter = 0
                hcounter = 0

                inserted = False

                for rec in records:

                    inserted = False

                    temperature = rec.temperature
                    humidity = rec.humidity
                    log_date_time = rec.timestamp

                    if temperature!=-99999.0:

                        if tmin == 'xx.x' or tmin > temperature:
                            tmin = temperature

                        if tmax == 'xx.x' or tmax < temperature:
                            tmax = temperature

                        if tsum is None:
                            tsum = temperature

                        else:
                            tsum = tsum + temperature

                        tcounter+=1

                    if humidity!=-99999.0:

                        if hmin == 'xx.x' or hmin > humidity:
                            hmin = humidity

                        if hmax == 'xx.x' or hmax < humidity:
                            hmax = humidity

                        if hsum is None:
                            hsum = humidity

                        else:
                            hsum = hsum + humidity
                        hcounter+=1

                    timediff = (log_date_time - start_rec.timestamp).total_seconds()

                    if timediff >= 900:

                        tavg = 'xx.x' if tcounter == 0 else round(tsum / tcounter * 100) / 100

                        havg = 'xx.x' if hcounter == 0 else round(hsum / hcounter * 100) / 100

                        result_data.append({
                            'branch_id': branch_id,
                            'room_id': room_id,
                            'sensor_id': sensor_id,
                            'sensor_Type': '01',
                            'logDateTime': log_date_time.strftime('%Y-%m-%d %H:%M:%S'),
                            'LAT': rec.latitude,
                            'LNG': rec.longitude,
                            'T': tavg,
                            'Tmin': tmin,
                            'Tmax': tmax,
                            'H': havg,
                            'Hmin': hmin,
                            'Hmax': hmax,
                        })

                        start_rec = rec
                        tcounter = 0
                        hcounter = 0
                        tsum = hsum = None
                        tmin = tmax = hmin = hmax = 'xx.x'

                if not inserted:

                    tavg = 'xx.x' if tcounter == 0 else round(tsum / tcounter * 100) / 100

                    havg = 'xx.x' if hcounter == 0 else round(hsum / hcounter * 100) / 100

                    result_data.append({
                        'branch_id': branch_id,
                        'room_id': room_id,
                        'sensor_id': sensor_id,
                        'sensor_Type': '01',
                        'logDateTime': log_date_time.strftime('%Y-%m-%d %H:%M:%S'),
                        'LAT': rec.latitude,
                        'LNG': rec.longitude,
                        'T': tavg,
                        'Tmin': tmin,
                        'Tmax': tmax,
                        'H': havg,
                        'Hmin': hmin,
                        'Hmax': hmax,
                    })

        loop_date += one_day_td

    return result_data


def prepare_data(branch_id,room_id,sensor_id,start_date,end_date):

    result_data = []
    sensor_type = get_sensor_type(branch_id, room_id)

    if sensor_type == '02':
        sid = int(sensor_id)

        if sid > 8 or sid < 1:
            abort(400)

        result_data = get_fixed_sensor_data(branch_id,room_id,sensor_id,start_date,end_date)

    elif sensor_type == '01':
        result_data = get_moving_sensor_data(branch_id,room_id,sensor_id,start_date,end_date)

    return result_data


@app.route('/',methods=['GET'])
def get_data():

    # @TODO Check if client address is valid

    args = request.args
    branch_id = args.get('branch_id', None)
    room_id = args.get('room_id', None)
    sensor_id = args.get('sensor_id', None)
    start_date = args.get('startdate', None)
    end_date = args.get('enddate', None)

    if not (branch_id and branch_id.isdigit()):
        abort(400)

    if not (room_id and room_id.isdigit()):
        abort(400)

    if not (sensor_id and sensor_id.isdigit()):
        abort(400)

    if not start_date:
        abort(400)

    if not end_date:
        return abort(400)

    try:
        start_date = datetime.strptime(start_date, '%Y-%m-%d').date()
        end_date = datetime.strptime(end_date, '%Y-%m-%d').date()

    except:
        abort(400)

    data = prepare_data(branch_id,room_id,sensor_id,start_date,end_date)

    return json.dumps(data)
    
if __name__ == '__main__':
	app.run()

