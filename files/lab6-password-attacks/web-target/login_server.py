"""Minimal login form for practicing Hydra's http-post-form module."""
import http.server
import urllib.parse

VALID_USERS = {"admin": "letmein", "sysadmin": "ChangeMe2024!"}

LOGIN_PAGE = """<!DOCTYPE html>
<html><head><title>CyberCorp Portal Login</title></head>
<body>
<h1>CyberCorp Portal</h1>
<form method="POST" action="/login">
  <input name="user" placeholder="username"><br>
  <input name="pass" type="password" placeholder="password"><br>
  <button type="submit">Login</button>
</form>
</body></html>
"""


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(LOGIN_PAGE.encode())

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length).decode()
        params = urllib.parse.parse_qs(body)
        user = params.get("user", [""])[0]
        pw = params.get("pass", [""])[0]
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        if VALID_USERS.get(user) == pw:
            self.wfile.write(b"<html><body>Welcome! Login successful. flag{lab6_hydra_web_login_cracked}</body></html>")
        else:
            self.wfile.write(b"<html><body>Invalid username or password</body></html>")

    def log_message(self, fmt, *args):
        pass


if __name__ == "__main__":
    server = http.server.HTTPServer(("0.0.0.0", 80), Handler)
    server.serve_forever()
