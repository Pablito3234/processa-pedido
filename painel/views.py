from django.http import JsonResponse
from django.shortcuts import render
from django.views import View

from pedidos.models import Pedido


class IndexView(View):
    def get(self, request):
        pedidos = Pedido.objects.prefetch_related('itens').all()[:50]
        return render(request, 'painel/index.html', {'pedidos': pedidos})


class OrdersJsonView(View):
    def get(self, request):
        pedidos = list(
            Pedido.objects.values('id', 'cliente', 'total', 'status')
            .order_by('-criado_em')[:20]
        )
        for p in pedidos:
            p['total'] = float(p['total'])
        return JsonResponse(pedidos, safe=False)
