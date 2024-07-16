import psycopg2, requests, datetime, logging,json

# define a Handler which writes INFO messages or higher to the sys.stderr
console = logging.StreamHandler()
# set a format which is simpler for console use
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
# tell the handler to use this format
console.setFormatter(formatter)
# add the handler to the root logger
logger = logging.getLogger()
logger.addHandler(console)
logger.setLevel(logging.INFO)

keys = ['branch_id', 'room_id', 'sensor_id', 'startdate', 'enddate']
columns = ['branch_id', 'room_id', 'sensor_id', 'sensor_type', 'logdatetime',
           'lat', 'lng', 't','h', 'tmax', 'tmin', 'hmax', 'hmin']

def get_sensor(conn,branch_id,room_id,sensor_id):
    sensor = None
    try:
        with conn.cursor() as cur:
            cur.execute('''select warehouse_id,room_id,sensor_id,url
                           from data.sensors
                           where warehouse_id=%s and room_id=%s and sensor_id=%s''',(branch_id,room_id,sensor_id))
            sensor = cur.fetchone()

    except:
        logger.exception('An error occurred during getting sensor')
    return sensor


def clean_data(data):
    if data[5]=='0000000000' or isinstance(data[5],str):
        data[5] = None
    if data[6]=='0000000000' or isinstance(data[6],str):
        data[6] = None
    for i in range(7,len(data)):
        if data[i] == 'xx.x':
            data[i] = None
    for i in range(3):
        data[i] = str(data[i])
    return data


def insert_data(conn, data):
#    print(data)
    with conn.cursor() as cur:
       print(data) 
       for d in data:
            try:
                row = [d[c] for c in columns]
                row = clean_data(row)
                print(row)
                cur.callproc('data.insert_data', row)
                conn.commit()
                return_id = cur.fetchone()[0]
                print(return_id)

                if return_id == -1:
                    logger.error('Data not inserted')
                    print(row)
                    print(cur.query)
            except psycopg2.errors.UniqueViolation as e:
                conn.rollback()
                print(e)
            except Exception as e:

                conn.rollback()
                logger.exception('An error ocurred while inserting data to db')



def fetch(session, url, args):
    params = dict(zip(keys, args))
    data = []
    try:
        resp = session.get(url, params=params)
        logger.info('Request sent to {}'.format(resp.url))
        if resp.status_code == 200:
            text = resp.text.lower()
            data = json.loads(text)
            logger.info('Data fetched successfully')
        return data
    except Exception as e:
        logger.exception('An error ocurred while sending request to server',exc_info=True)
        return []


def runner(branch_id,room_id,sensor_id,start_date,end_date):
    logger.info('Fetching data started ...')
    conn = None
    try:
        conn = psycopg2.connect(host='localhost',dbname='sensor', user='sensor', password='sensor')
    except:
        logger.exception('Cannot connect to database')

    if conn:
        session = requests.Session()
        sensor = get_sensor(conn,branch_id,room_id,sensor_id)
        if sensor:
            url = sensor[-1]
            if url:
                args = [branch_id,room_id,sensor_id,start_date,end_date]
                logger.info(f'Processing {url} with args: {args}')
                data = fetch(session, url, args)
                insert_data(conn, data)
        else:
            logger.info('Sensor with this information does not exists.')
        logger.info('Operation done successfully.')
        conn.close()


branch_id = input('Branch id: ')
room_id = input('Room id: ')
sensor_id = input('Sensor id: ')
start_date = input('Start date: ')
end_date = input('End date: ')
runner(branch_id,room_id,sensor_id,start_date,end_date)

