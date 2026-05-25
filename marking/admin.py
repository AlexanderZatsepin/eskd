from django.contrib import admin

from marking.models import Cabinet, Project, WireColor, WireEndpoint, WireType


@admin.register(Project)
class ProjectAdmin(admin.ModelAdmin):
    list_display = ["code", "order_number", "name", "updated_at"]
    search_fields = ["code", "order_number", "name"]


@admin.register(Cabinet)
class CabinetAdmin(admin.ModelAdmin):
    list_display = ["code", "project", "name", "description", "updated_at"]
    list_filter = ["project"]
    search_fields = ["code", "name", "description", "project__code"]


@admin.register(WireEndpoint)
class WireEndpointAdmin(admin.ModelAdmin):
    list_display = ["uid", "cabinet", "ref", "mark_1", "mark_2", "sync_status"]
    list_filter = ["sync_status", "cabinet__project"]
    search_fields = ["uid", "ref", "mark_1", "mark_2"]


@admin.register(WireType)
class WireTypeAdmin(admin.ModelAdmin):
    list_display = ["name", "description", "updated_at"]
    search_fields = ["name", "description"]


@admin.register(WireColor)
class WireColorAdmin(admin.ModelAdmin):
    list_display = ["name", "description", "updated_at"]
    search_fields = ["name", "description"]
