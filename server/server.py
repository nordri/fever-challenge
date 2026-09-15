import os
import ssl
from flask import Flask, request
from werkzeug.serving import run_simple, WSGIRequestHandler

app = Flask(__name__)

@app.route('/')
def echo():
    return f'Domain: {request.host}, Client IP: {request.remote_addr}', 200

if __name__ == '__main__':
    ctx = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
    ctx.load_cert_chain('certs/server.crt', 'certs/server.key')
    run_simple('0.0.0.0', 5000, app, request_handler=WSGIRequestHandler, ssl_context=ctx)
