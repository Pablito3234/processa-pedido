from django.urls import path, include

urlpatterns = [
    path('', include('painel.urls')),
    path('', include('loja.urls')),
]
