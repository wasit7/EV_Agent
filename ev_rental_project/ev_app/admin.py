# ev_app/admin.py
from django.contrib import admin
from .models import UserProfile, EVCar, Transaction

@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ('user', 'full_name', 'nickname', 'license_id', 'phone')

@admin.register(EVCar)
class EVCarAdmin(admin.ModelAdmin):
    list_display = ('model_name', 'status', 'price_per_day', 'range_km')
    list_filter = ('status',)

@admin.register(Transaction)
class TransactionAdmin(admin.ModelAdmin):
    list_display = ('id', 'customer', 'car', 'type', 'status', 'appointment_date', 'created_at')
    list_filter = ('status', 'type')
