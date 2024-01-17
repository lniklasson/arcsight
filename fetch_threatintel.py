#!/usr/bin/env python3

__author__ = "Lars Niklasson"
__copyright__ = "Copyright 2024, Qi Security AB"
__license__ = "GPL"
__version__ = "1.0.0"

import datetime
import os
import requests
from bs4 import BeautifulSoup

'''
URL of the threatintel web-page which provides link to
all json. It would have been tiring to
download each json manually.
We first crawl the webpage to extract
all the links and then download jsons.
'''

# specify the URL of the threatintel here
threatintel_url = "https://www.circl.lu/doc/misp/feed-osint/"

# define the direcroty where you want to use as home
home_dir = "/home/lani/feed/"

# Enable debug, printing info to the screen
debug = True

############
### DEFs ###
############

def create_dir():
    current_time = datetime.datetime.now()
    s_datetime = (str(current_time).replace(" ","T").replace(":","").split(".")[0])
    #2024-01-17T140631

    directory = home_dir + s_datetime
    os.mkdir(directory)
    os.chdir(directory)
    if debug:
        print("Directory '% s' created" % directory)
    return s_datetime,directory


def get_json_links():

    # create response object
    r = requests.get(threatintel_url)

    # create beautiful-soup object
    soup = BeautifulSoup(r.content,'html5lib')

    # find all links on web-page
    links = soup.findAll('a')

    # filter the link sending with .mp4
    json_links = [threatintel_url + link['href'] for link in links if link['href'].endswith('json')]

    return json_links


def download_json_series(json_links,directory):

    for link in json_links:

        '''iterate through all links in json_links
        and download them one by one'''

        # obtain filename by splitting url and getting
        # last string
        file_name = link.split('/')[-1]

        if debug:
            print( "Downloading file:%s"%file_name)

        # create response object
        r = requests.get(link, stream = True)

        # download started
        with open(file_name, 'wb') as f:
            for chunk in r.iter_content(chunk_size = 1024*1024):
                if chunk:
                    f.write(chunk)

        if debug:
            print( "%s downloaded!\n"%file_name )

        if debug:
            break

    if debug:
        print ("All json downloaded!")
    return


def tar_jsons(s_datetime):
    os.system("tar cfz " + home_dir + "/" + s_datetime + ".tar.gz .")
    if debug:
        print("\nFile " + home_dir + s_datetime + ".tar.gz created!")
    return

def delete_jsons(directory):
    import shutil
    #location = directory
    #dir = ""
    #path = os.path.join(location, dir)
    shutil.rmtree(directory)
    print("Directory " + directory + " is deleted.")
    return

############
### MAIN ###
############

if __name__ == "__main__":
    if debug:
        print("Debug mode enabled, only one file will be downloaded.\n")
    s_datetime,directory = create_dir()
    json_links = get_json_links()
    download_json_series(json_links,directory)
    tar_jsons(s_datetime)
    delete_jsons(directory)
    if debug:
        print("\n1. Move the tar file over to the airgap'ed environment")
        print("2. Install httpd, enable and start httpd")
        print("3. Make sure firewall is blocking port 80, this only need to be reachable via localhost")
        print("4. Create the folder /var/www/html/feed")
        print("5. Untar the file into this directory")
        print("6. Install ArcSight Threat Acceleration Connector")
        print("7. Enter http://localhost as Threat Intel URL")
        print("8. Start the Connector and in ESM configure the Connecotr with a user as \"Model import user\"")
        print("9. Start the import on the Connector (under Send Command/Model Import Connector/Start Import)")
