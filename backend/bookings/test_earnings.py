from datetime import date, time, timedelta
from unittest.mock import patch

from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from accounts.models import Role
from accounts.tests import ProfilesTableMixin, make_profile
from grounds.models import Ground

from .models import Booking

TODAY = date(2026, 10, 15)  # a Thursday; that week runs Sun 11 – Sat 17 Oct


def client_for(profile):
    client = APIClient()
    client.force_authenticate(user=profile)
    return client


@patch('bookings.views.timezone.localdate', return_value=TODAY)
class EarningsChartTests(ProfilesTableMixin, TestCase):
    def setUp(self):
        self.owner = make_profile(Role.GROUND_OWNER)
        self.customer = make_profile()
        self.arena = self.ground('Arena', self.owner)
        self.hub = self.ground('Hub', self.owner)
        self.elsewhere = self.ground('Elsewhere', make_profile(Role.GROUND_OWNER))

    def ground(self, name, owner):
        return Ground.objects.create(owner=owner, name=name, area='Patan', latitude='27.67', longitude='85.32',
                                     morning_price=1000, day_price=1000, evening_price=1000,
                                     status=Ground.Status.APPROVED)

    def booking(self, day, price=1000, ground=None, hour=8, **fields):
        return Booking.objects.create(ground=ground or self.arena, customer=self.customer, date=day,
                                      start_time=time(hour), price=price, **fields)

    def chart(self, period, **query):
        response = client_for(self.owner).get('/api/owner/earnings/', {'period': period, **query})
        self.assertEqual(response.status_code, 200, response.json())
        return response.json()

    def test_daily_bars_end_today_and_count_only_money_earned(self, _today):
        self.booking(TODAY)                                   # played this morning
        self.booking(TODAY - timedelta(days=1), price=1500)
        self.booking(TODAY - timedelta(days=1), price=500, ground=self.hub, hour=9)
        self.booking(TODAY - timedelta(days=2), status='cancelled', refund_amount=1000)          # cash: earns 0
        self.booking(TODAY - timedelta(days=2), hour=9, status='cancelled', refund_amount=500,
                     payment_method='esewa', payment_status='paid')                              # kept 500
        self.booking(TODAY - timedelta(days=3), status='pending', payment_method='khalti')       # never paid
        self.booking(TODAY + timedelta(days=1))                                                  # not played yet
        self.booking(TODAY - timedelta(days=1), price=9999, ground=self.elsewhere)               # someone else's

        with patch('bookings.views.slot_has_started', return_value=True):
            body = self.chart('day')
        bars = body['bars']
        self.assertEqual((len(bars), bars[-1]['start'], bars[0]['start']), (14, '2026-10-15', '2026-10-02'))
        by_day = {bar['start']: (bar['earnings'], bar['games']) for bar in bars}
        self.assertEqual(by_day['2026-10-15'], ('1000.00', 1))
        self.assertEqual(by_day['2026-10-14'], ('2000.00', 2))
        self.assertEqual(by_day['2026-10-13'], ('500.00', 0))
        self.assertEqual(by_day['2026-10-12'], ('0.00', 0))
        self.assertEqual(body['total'], '3500.00')

        with patch('bookings.views.slot_has_started', return_value=True):
            self.assertEqual(self.chart('day', ground=self.hub.id)['total'], '500.00')

    def test_games_later_today_are_not_counted_yet(self, _today):
        self.booking(TODAY, hour=20)
        with patch('bookings.views.slot_has_started', return_value=False):
            self.assertEqual(self.chart('day')['total'], '0.00')

    def test_weekly_monthly_yearly_buckets_and_previous_total(self, _today):
        self.booking(date(2026, 10, 11))  # Sunday: this week
        self.booking(date(2026, 10, 10))  # Saturday: last week
        self.booking(date(2026, 1, 5))
        self.booking(date(2025, 9, 1))    # 13 months ago: before the monthly bars
        self.booking(date(2021, 6, 1))    # 5 years ago: before the yearly bars

        week = self.chart('week')
        self.assertEqual((len(week['bars']), week['bars'][-1]['start']), (12, '2026-10-11'))
        self.assertEqual((week['bars'][-1]['earnings'], week['bars'][-2]['earnings']), ('1000.00', '1000.00'))

        month = self.chart('month')
        self.assertEqual([month['bars'][i]['start'] for i in (0, -1)], ['2025-11-01', '2026-10-01'])
        self.assertEqual((month['bars'][-1]['earnings'], month['total'], month['previous_total']),
                         ('2000.00', '3000.00', '1000.00'))

        year = self.chart('year')
        self.assertEqual([bar['start'] for bar in year['bars']],
                         ['2022-01-01', '2023-01-01', '2024-01-01', '2025-01-01', '2026-01-01'])
        self.assertEqual((year['bars'][-1]['earnings'], year['bars'][-2]['earnings'], year['previous_total']),
                         ('3000.00', '1000.00', '1000.00'))

    def test_bad_period_and_customers_are_refused(self, _today):
        self.assertEqual(client_for(self.owner).get('/api/owner/earnings/', {'period': 'hour'}).status_code, 400)
        self.assertEqual(client_for(self.customer).get('/api/owner/earnings/').status_code, 403)


class UnpaidHoldEarningsTests(ProfilesTableMixin, TestCase):
    def test_week_earnings_skip_unpaid_online_holds(self):
        owner = make_profile(Role.GROUND_OWNER)
        ground = Ground.objects.create(owner=owner, name='Arena', area='Patan', latitude='27.67',
                                       longitude='85.32', morning_price=1, day_price=1, evening_price=1,
                                       status=Ground.Status.APPROVED)
        hold = Booking.objects.create(ground=ground, customer=make_profile(), date=timezone.localdate(),
                                      start_time=time(23), price=1000, status='pending', payment_method='esewa')
        self.assertEqual(hold.owner_keeps, 0)
        self.assertEqual(client_for(owner).get('/api/owner/summary/').json()['week_earnings'], '0.00')
