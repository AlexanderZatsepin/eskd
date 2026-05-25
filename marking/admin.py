from django.contrib import admin

from marking.models import Drawing, Project, WireColor, WireEndpoint, WireType


@admin.register(Project)
class ProjectAdmin(admin.ModelAdmin):
    list_display = ["project_id", "order_number", "name", "updated_at"]
    search_fields = ["project_id", "order_number", "name"]


@admin.register(Drawing)
class DrawingAdmin(admin.ModelAdmin):
    list_display = ["dwg_id", "project", "name", "file_name", "updated_at"]
    list_filter = ["project"]
    search_fields = ["dwg_id", "name", "file_name", "project__project_id"]


@admin.register(WireEndpoint)
class WireEndpointAdmin(admin.ModelAdmin):
    list_display = ["endpoint_id", "drawing", "ref_id", "mark_1", "mark_2", "position", "sync_status"]
    list_filter = ["sync_status", "drawing__project"]
    search_fields = ["endpoint_id", "ref_id", "mark_1", "mark_2", "position"]


@admin.register(WireType)
class WireTypeAdmin(admin.ModelAdmin):
    list_display = ["name", "description", "updated_at"]
    search_fields = ["name", "description"]


@admin.register(WireColor)
class WireColorAdmin(admin.ModelAdmin):
    list_display = ["name", "description", "updated_at"]
    search_fields = ["name", "description"]
