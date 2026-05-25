from django.contrib import admin

from marking.models import Cabinet, Project, WireColor, WireEndpoint, WireType


@admin.register(Project)
class ProjectAdmin(admin.ModelAdmin):
    list_display = ["project_code", "name", "is_active", "code", "updated_at"]
    list_filter = ["is_active"]
    search_fields = ["project_code", "code", "name"]
    fields = ["project_code", "name", "is_active", "code", "created_at", "updated_at"]
    readonly_fields = ["code", "created_at", "updated_at"]


@admin.register(Cabinet)
class CabinetAdmin(admin.ModelAdmin):
    list_display = ["cabinet_code", "code", "project", "name", "description", "updated_at"]
    list_filter = ["project"]
    search_fields = ["cabinet_code", "code", "name", "description", "project__code", "project__project_code"]
    readonly_fields = ["code", "created_at", "updated_at"]


@admin.register(WireEndpoint)
class WireEndpointAdmin(admin.ModelAdmin):
    list_display = ["uid", "cabinet", "ref", "mark_1", "mark_2", "sync_status"]
    list_filter = ["sync_status", "cabinet__project"]
    search_fields = ["uid", "ref", "mark_1", "mark_2"]
    readonly_fields = ["uid", "created_at", "updated_at"]


@admin.register(WireType)
class WireTypeAdmin(admin.ModelAdmin):
    list_display = ["name", "description", "updated_at"]
    search_fields = ["name", "description"]


@admin.register(WireColor)
class WireColorAdmin(admin.ModelAdmin):
    list_display = ["name", "description", "updated_at"]
    search_fields = ["name", "description"]
