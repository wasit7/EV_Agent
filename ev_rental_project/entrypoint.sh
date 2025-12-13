#!/bin/sh

echo "Waiting for postgres..."
while ! nc -z db 5432; do
  sleep 0.1
done
echo "PostgreSQL started"

echo "Applying database migrations..."
python manage.py makemigrations ev_app
python manage.py migrate

echo "Loading inventory data..."
python manage.py load_inventory

echo "Starting server..."
exec python manage.py runserver 0.0.0.0:8000
