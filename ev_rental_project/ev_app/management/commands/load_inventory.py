import csv
import os
from django.core.management.base import BaseCommand
from ev_app.models import EVCar

class Command(BaseCommand):
    help = 'Load EV inventory from CSV'

    def handle(self, *args, **options):
        file_path = '/app/data/cars.csv'
        if not os.path.exists(file_path):
            self.stdout.write(self.style.WARNING(f'Data file not found at {file_path}'))
            return
        
        with open(file_path, 'r') as f:
            reader = csv.DictReader(f)
            count = 0
            for row in reader:
                obj, created = EVCar.objects.update_or_create(
                    model_name=row['model_name'],
                    defaults={
                        'range_km': int(row['range_km']),
                        'price_per_day': float(row['price_per_day']),
                        'status': row['status']
                    }
                )
                if created:
                    count += 1
            
        self.stdout.write(self.style.SUCCESS(f'Successfully loaded/updated inventory.'))
