from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [
        ("marking", "0007_wirecolor_wiretype_alter_wireendpoint_mark_1_and_more"),
    ]

    operations = [
        migrations.RemoveField(
            model_name="wireendpoint",
            name="position",
        ),
    ]
