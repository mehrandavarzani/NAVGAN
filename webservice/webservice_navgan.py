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

app = Flask(__name__)

app.config['SQLALCHEMY_BINDS'] = {
    'navgan': f'postgres://{PSQL_USER}:{PSQL_PASS}@localhost/navgan'
}

db = SQLAlchemy(app)

try:
    navgan_eng = db.get_engine(app,'navgan')
except:
    app.logger.exception('Error during making connection to navgan')
    abort(500)

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
            query = text(f'''SELECT timestamp,temperature,
                             humidity,longitude,latitude
                             FROM data.{table_name} where device_id=:sid''')

            try:
                result = navgan_eng.execute(query, sid=device_id)

            except:
                app.logger.exception('An error occurred while getting data')
#                abort(500)

            Record = namedtuple('Record', result.keys())
            records = [Record(*r) for r in result.fetchall()]

            if records:

                start_rec = records[0]

                tmin = tmax = hmin = hmax = 'xx.x'

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

                        tsum = tsum + temperature
                        tcounter+=1

                    if humidity!=-99999.0:

                        if hmin == 'xx.x' or hmin > humidity:
                            hmin = humidity

                        if hmax == 'xx.x' or hmax < humidity:
                            hmax = humidity

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

    result_data = get_moving_sensor_data(branch_id,room_id,sensor_id,start_date,end_date)

    return result_data


@app.route('/',methods=['GET'])
def get_data():

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
	app.run(port=4545)

