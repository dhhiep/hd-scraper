## DOCUMENTATION
This is a basic scraper script base on selenium with chrome webdriver.
Support:
    1. Page load content by javascript.
    2. Capture screenshot and send to emails.
    3. Redis store and restore to inscrease speed.
    4. Support store and restore session/cookies.

## ENVIRONMENT SETUP
On development environment, we use the dotenv to setup environment variables.
At root path, we create a file `.env` with content

```
SENDGRID_API_KEY=xxx
EMAILS="mai1@mail.com,mai2@mail.com"
REDIS_URL=xxx
SELENIUM_TYPE=desktop # or heroku, ubuntu
```

Run script

```bash
ruby main.rb
```

## HOST INFORMATION
```
OS: macOS Mojave
Ruby: 2.3.7
RVM: rvm 1.29.4
```
