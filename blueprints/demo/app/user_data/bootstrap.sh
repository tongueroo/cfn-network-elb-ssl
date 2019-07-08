#!/bin/bash
yum install -y httpd
echo "hello world" > /var/www/html/index.html
echo "test" > /var/www/html/test.html
service httpd start
