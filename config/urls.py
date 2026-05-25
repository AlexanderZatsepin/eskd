from django.contrib import admin
from django.urls import include, path
from rest_framework.authtoken.views import obtain_auth_token
from rest_framework.routers import DefaultRouter

from marking.views import (
    DrawingViewSet,
    ProjectViewSet,
    WireColorViewSet,
    WireEndpointViewSet,
    WireTypeViewSet,
)
from marking.web_views import cambrics_report


router = DefaultRouter()
router.register("projects", ProjectViewSet, basename="project")
router.register("drawings", DrawingViewSet, basename="drawing")
router.register("wire-types", WireTypeViewSet, basename="wire-type")
router.register("wire-colors", WireColorViewSet, basename="wire-color")
router.register("wire-endpoints", WireEndpointViewSet, basename="wire-endpoint")

urlpatterns = [
    path("admin/", admin.site.urls),
    path("reports/cambrics/", cambrics_report, name="cambrics-report"),
    path("api/auth/token/", obtain_auth_token, name="api-token-auth"),
    path("api/", include(router.urls)),
]
