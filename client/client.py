import os
import ssl
import requests

class Client:
    def __init__(self, server_addresses):
        self.server_addresses = server_addresses
        self.session = requests.Session()
        self.session.verify = 'certs/server.crt'

    def request(self, url):
        try:
            response = self.session.get(url)
            print(f'Response from {url}: {response.text}')
        except Exception as e:
            print(f'Error while connecting to {url}: {e}')

    def run(self):
        for server_address in self.server_addresses:
            url = f'https://{server_address}:5000'
            self.request(url)

if __name__ == '__main__':
    server_addresses = ['server', 'server.example.com', 'server.local']
    client = Client(server_addresses)
    client.run()

