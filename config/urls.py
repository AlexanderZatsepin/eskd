from django.contrib import admin
from django.urls import include, path
from rest_framework.authtoken.views import obtain_auth_token
from rest_framework.routers import DefaultRouter

from marking.views import (
    CabinetViewSet,
    ProjectViewSet,
    WireColorViewSet,
    WireEndpointViewSet,
    WireTypeViewSet,
)
from marking.web_views import cambrics_report


admin.site.site_header = "Администрирование ESKD"
admin.site.site_title = "ESKD"
admin.site.index_title = "Панель управления"

router = DefaultRouter()
router.register("projects", ProjectViewSet, basename="project")
router.register("cabinets", CabinetViewSet, basename="cabinet")
router.register("wire-types", WireTypeViewSet, basename="wire-type")
router.register("wire-colors", WireColorViewSet, basename="wire-color")
router.register("wire-endpoints", WireEndpointViewSet, basename="wire-endpoint")

urlpatterns = [
    path("admin/", admin.site.urls),
    path("reports/cambrics/", cambrics_report, name="cambrics-report"),
    path("api/auth/token/", obtain_auth_token, name="api-token-auth"),
    path("api/", include(router.urls)),
]
