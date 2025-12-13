# ev_app/models.py
from django.db import models
from django.contrib.auth.models import User

class UserProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    full_name = models.CharField(max_length=100, blank=True, null=True)
    nickname = models.CharField(max_length=50, blank=True, null=True)
    license_id = models.CharField(max_length=50, blank=True, null=True)
    phone = models.CharField(max_length=20, blank=True, null=True)

    def __str__(self):
        name = self.full_name or self.user.username
        return f"{name} (Nick: {self.nickname}) (License: {self.license_id})"

class EVCar(models.Model):
    STATUS_CHOICES = [
        ('AVAILABLE', 'Available'),
        ('RENTED', 'Rented'),
        ('MAINTENANCE', 'Maintenance'),
    ]
    model_name = models.CharField(max_length=100)
    range_km = models.IntegerField()
    price_per_day = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='AVAILABLE')

    def __str__(self):
        return f"{self.model_name} ({self.status})"

class Transaction(models.Model):
    TYPE_CHOICES = [('TEST_DRIVE', 'Test Drive'), ('PURCHASE', 'Purchase')]
    STATUS_CHOICES = [('DRAFT', 'Draft'), ('CONFIRMED', 'Confirmed'), ('CANCELLED', 'Cancelled')]

    customer = models.ForeignKey(UserProfile, on_delete=models.CASCADE)
    car = models.ForeignKey(EVCar, on_delete=models.CASCADE)
    type = models.CharField(max_length=20, choices=TYPE_CHOICES)
    
    # --- Date Fields Requirement Met Here ---
    appointment_date = models.DateTimeField(null=True, blank=True) # For appointment/deliverable
    created_at = models.DateTimeField(auto_now_add=True)           # For record creation
    # ----------------------------------------

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='DRAFT')

    def __str__(self):
        return f"{self.get_type_display()} - {self.car.model_name} ({self.status})"
