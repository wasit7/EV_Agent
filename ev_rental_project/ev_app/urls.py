# ev_app/urls.py
from django.urls import path
from . import views

urlpatterns = [
    path('', views.chat_view, name='chat'),
    path('chat/', views.chat_view, name='chat_view'),
    path('confirm/', views.confirm_transaction, name='confirm_transaction'),
]
