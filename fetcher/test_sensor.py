import datetime
import logging
import json
import requests


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


def fetch(url, args):
    params = dict(zip(keys, args))
    data = []
    try:
        logger.info('Sending request to server')
        resp = requests.get(url, params=params)
        logger.info('Request sent to {}'.format(resp.url))
        logger.info('Server returend response with status code: {}'.format(resp.status_code))

        if resp.status_code == 200:
            text = resp.text.lower()
            data = json.loads(text)
            logger.info('Data fetched successfully')
            logger.info('Server returend {} bytes of data'.format(len(text)))
            logger.info('Top 5 rows of data : {}'.format(data[:5]))

    except requests.exceptions.InvalidURL:
        logger.exception('InvalidURL: url is invalid',exc_info=False)

    except requests.exceptions.ConnectTimeout:
        logger.exception('ConnectionTimeout: The request timed out while trying to connect to the remote server',exc_info=False)

    except requests.exceptions.ReadTimeout:
        logger.exception('ReadTimeout: The server did not send any data in the allotted amount of time.',exc_info=False)

    except requests.exceptions.ContentDecodingError:
        logger.exception('ReadTimeout: Failed to decode response content.',exc_info=False)
        logger.info('Response: {}'.format(resp.content.decode('utf8')))

    except json.JSONDecodeError:
        logger.exception('JSONDecodeError: Failed to decode response content.',exc_info=False)
        logger.info('Response: {}'.format(resp.content.decode('utf8')))

    except Exception:
        logger.exception('An error ocurred while sending request to server',exc_info=True)




if __name__ == '__main__':

    url = input('URL : ')
    branch_id = input('Branch id: ')
    room_id = input('Room id: ')
    sensor_id = input('Sensor id: ')
    start_date = input('Start date: ')
    end_date = input('End date: ')

    if not url.startswith('http'):
        url = 'http://'+url

    logger.info('Starting')

    args = [branch_id,room_id,sensor_id,start_date,end_date]

    fetch(url,args)

    logger.info('Exiting')

