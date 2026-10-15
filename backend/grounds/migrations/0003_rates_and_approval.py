from django.db import migrations, models


def copy_price_and_approve_existing(apps, schema_editor):
    """Existing grounds keep one rate for the whole day and stay visible:
    they were listed before approval existed."""
    Ground = apps.get_model('grounds', 'Ground')
    for ground in Ground.objects.all():
        ground.morning_price = ground.evening_price = ground.day_price
        ground.status = 'approved'
        ground.save(update_fields=['morning_price', 'evening_price', 'status'])


class Migration(migrations.Migration):

    dependencies = [
        ('grounds', '0002_favourite'),
    ]

    operations = [
        migrations.RenameField('ground', 'price_per_hour', 'day_price'),
        migrations.AlterField(
            model_name='ground',
            name='day_price',
            field=models.DecimalField(decimal_places=2, help_text='Per hour, 10 AM – 4 PM.', max_digits=8),
        ),
        migrations.AddField(
            model_name='ground',
            name='morning_price',
            field=models.DecimalField(decimal_places=2, max_digits=8, null=True),
        ),
        migrations.AddField(
            model_name='ground',
            name='evening_price',
            field=models.DecimalField(decimal_places=2, max_digits=8, null=True),
        ),
        migrations.AddField(
            model_name='ground',
            name='ownership_document',
            field=models.CharField(
                blank=True, max_length=255,
                help_text='Photo of the lalpurja (land ownership) or lease paper, in the private '
                          '"ground-documents" storage bucket.'),
        ),
        migrations.AddField(
            model_name='ground',
            name='status',
            field=models.CharField(
                choices=[('pending', 'Waiting for approval'), ('approved', 'Approved'), ('rejected', 'Rejected')],
                default='pending', max_length=8),
        ),
        migrations.AddField(
            model_name='ground',
            name='review_note',
            field=models.CharField(blank=True, max_length=255,
                                   help_text='Why it was rejected. The owner sees this in the app.'),
        ),
        migrations.AddField(
            model_name='ground',
            name='reviewed_at',
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.RunPython(copy_price_and_approve_existing, migrations.RunPython.noop),
        migrations.AlterField(
            model_name='ground',
            name='morning_price',
            field=models.DecimalField(decimal_places=2, help_text='Per hour, before 10 AM.', max_digits=8),
        ),
        migrations.AlterField(
            model_name='ground',
            name='evening_price',
            field=models.DecimalField(decimal_places=2, help_text='Per hour, from 4 PM (peak time).', max_digits=8),
        ),
    ]
