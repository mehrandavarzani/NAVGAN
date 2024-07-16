import psycopg2, time, schedule, requests, logging, datetime, schedule,json

logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
                    datefmt='%Y-%m-%d %H:%M',
                    filename='fetcher.log',
                    filemode='a')
# define a Handler which writes INFO messages or higher to the sys.stderr
console = logging.StreamHandler()
console.setLevel(logging.INFO)
# set a format which is simpler for console use
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
# tell the handler to use this format
console.setFormatter(formatter)
# add the handler to the root logger
logging.getLogger().addHandler(console)

logger = logging.getLogger()

keys = ['branch_id', 'room_id', 'sensor_id', 'startdate', 'enddate']
columns = ['branch_id', 'room_id', 'sensor_id', 'sensor_type', 'logdatetime',
           'lat', 'lng', 't','h', 'tmax', 'tmin', 'hmax', 'hmin']


def get_sensors(conn):
    sensors = []
    try:
        with conn.cursor() as cur:
            cur.execute('select warehouse_id,room_id,sensor_id,url from data.sensors')
            sensors = cur.fetchall()

    except:
        logger.exception('An error occurred during getting sensors')
    return sensors


def clean_data(data):
    if data[5]=='0000000000' or isinstance(data[5],str):
        data[5] = None
    if data[6]=='0000000000' or isinstance(data[6],str):
        data[6] = None
    for i in range(7,len(data)):
        if data[i] == 'xx.x':
            data[i] = None
    for i in range(3):
        data[i]=str(data[i])

    return data


def insert_data(conn, data):
    with conn.cursor() as cur:
        for d in data:
            try:
                row = [d[c] for c in columns]
                row = clean_data(row)
                cur.callproc('data.insert_data', row)
                conn.commit()
            except psycopg2.errors.UniqueViolation:
                conn.rollback()
            except Exception as e:
                conn.rollback()
                logger.exception('An error ocurred while inserting data to db')


def fetch(session, url, args):
    params = dict(zip(keys, args))
    try:
        resp = session.get(url, params=params,timeout=10)
        if resp.status_code == 200:
            text = resp.text.lower()
            data = json.loads(text)
            return data
        else:
            return []
    except Exception as e:
        logger.exception('An error ocurred during fetching data from {}'.format(url))
        return []

def runner():
    logger.info('Fetching new data ...')
    conn = None
    try:
        conn = psycopg2.connect(host='localhost',dbname='sensor', user='sensor', password='sensor')

    except:
        logger.exception('Cannot connect to database')
    if conn:
        sensors = get_sensors(conn)
        session = requests.Session()
        today = datetime.datetime.now().date() # + datetime.timedelta(days=1)
        last_week = today - datetime.timedelta(days=7)
        for s in sensors:
            url = s[-1]
            if url:
                args = list(s[:-1]) + [last_week, today]
                logger.info(f'Processing {url} with args: {args}')
                data = fetch(session, url, args)
                insert_data(conn, data)
        logger.info('Data fetched successfully')
        conn.close()

runner()
schedule.every(15).minutes.do(runner)

while True:
    schedule.run_pending()
    time.sleep(1)

