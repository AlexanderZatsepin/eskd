from django.db import models


class Project(models.Model):
    project_id = models.CharField(max_length=64)
    order_number = models.CharField(max_length=64, blank=True)
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["project_id"]
        constraints = [
            models.UniqueConstraint(
                fields=["project_id", "order_number"],
                name="unique_project_order_number",
            )
        ]

    def __str__(self):
        return f"{self.project_id} - {self.name}"


class Drawing(models.Model):
    project = models.ForeignKey(Project, on_delete=models.CASCADE, related_name="drawings")
    dwg_id = models.CharField(max_length=128)
    name = models.CharField(max_length=255, blank=True)
    file_name = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["project__project_id", "dwg_id"]
        constraints = [
            models.UniqueConstraint(
                fields=["project", "dwg_id"],
                name="unique_drawing_per_project",
            )
        ]

    def __str__(self):
        return f"{self.project.project_id} / {self.dwg_id}"


class WireEndpoint(models.Model):
    class SyncStatus(models.TextChoices):
        NEW = "NEW", "New"
        SYNCED = "SYNCED", "Synced"
        DIRTY = "DIRTY", "Dirty"
        ERROR = "ERROR", "Error"

    endpoint_id = models.CharField(max_length=32, primary_key=True)
    drawing = models.ForeignKey(Drawing, on_delete=models.CASCADE, related_name="wire_endpoints")
    ref_id = models.CharField(max_length=64)
    mark = models.CharField(max_length=128)
    position = models.CharField(max_length=64)
    wire_type = models.CharField(max_length=64, blank=True)
    wire_color = models.CharField(max_length=32, blank=True)
    sync_status = models.CharField(
        max_length=16,
        choices=SyncStatus.choices,
        default=SyncStatus.NEW,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["drawing__project__project_id", "drawing__dwg_id", "ref_id", "mark"]
        indexes = [
            models.Index(fields=["ref_id"]),
            models.Index(fields=["sync_status"]),
        ]

    def __str__(self):
        return f"{self.endpoint_id}: {self.mark}"
