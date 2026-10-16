from datetime import time, timedelta

from django.test import TestCase
from django.utils import timezone

from accounts.models import Role
from accounts.tests import ProfilesTableMixin, make_profile
from bookings.models import Booking
from notifications.models import Notification

from .models import Review
from .test_maintenance_events import client_for, make_ground


class ReviewTests(ProfilesTableMixin, TestCase):
    def setUp(self):
        self.owner = make_profile(Role.GROUND_OWNER, 'Owner')
        self.customer = make_profile(Role.CUSTOMER, 'Hari')
        self.ground = make_ground(self.owner)
        self.url = f'/api/grounds/{self.ground.id}/reviews/'

    def play(self, customer=None, days_ago=1, **fields):
        return Booking.objects.create(ground=self.ground, customer=customer or self.customer,
                                      date=timezone.localdate() - timedelta(days=days_ago), start_time=time(8),
                                      price=1000, **fields)

    def review(self, rating=5, comment='Great turf', customer=None):
        return client_for(customer or self.customer).post(self.url, {'rating': rating, 'comment': comment},
                                                          format='json')

    def test_only_customers_who_played_can_review(self):
        self.assertEqual(self.review().status_code, 400)
        self.play(days_ago=-2)  # booked, not played yet
        self.assertEqual(self.review().status_code, 400)
        self.assertFalse(client_for(self.customer).get(self.url).json()['can_review'])

        self.play(days_ago=3)
        self.assertTrue(client_for(self.customer).get(self.url).json()['can_review'])
        self.assertEqual(self.review().status_code, 201)

    def test_cancelled_or_unpaid_games_dont_count(self):
        self.play(status=Booking.Status.CANCELLED)
        self.play(days_ago=2, status=Booking.Status.PENDING, payment_method='esewa')
        self.assertEqual(self.review().status_code, 400)

    def test_writing_again_updates_and_owner_is_told_once(self):
        self.play()
        self.review(4, 'Good')
        response = self.review(2, '  Lights were off  ')
        self.assertEqual(response.status_code, 200)
        review = Review.objects.get()
        self.assertEqual((review.rating, review.comment), (2, 'Lights were off'))
        notices = Notification.objects.filter(recipient=self.owner, kind=Notification.Kind.REVIEW)
        self.assertEqual(notices.count(), 1)
        self.assertIn('4★', notices.get().title)

    def test_rating_must_be_one_to_five(self):
        self.play()
        self.assertEqual(self.review(0).status_code, 400)
        self.assertEqual(self.review(6).status_code, 400)

    def test_average_breakdown_and_ground_list(self):
        other = make_profile(Role.CUSTOMER, 'Sita')
        self.play()
        self.play(customer=other, days_ago=2)
        self.review(5)
        self.review(4, customer=other)

        body = client_for(self.customer).get(self.url).json()
        self.assertEqual((body['rating'], body['review_count']), (4.5, 2))
        self.assertEqual(body['stars'], {'5': 1, '4': 1, '3': 0, '2': 0, '1': 0})
        self.assertEqual(body['my_review']['rating'], 5)
        self.assertEqual({r['customer_name'] for r in body['reviews']}, {'Hari', 'Sita'})

        ground = client_for(self.customer).get('/api/grounds/').json()[0]
        self.assertEqual((ground['rating'], ground['review_count']), (4.5, 2))

    def test_no_reviews_yet_and_delete(self):
        listed = client_for(self.customer).get('/api/grounds/').json()[0]
        self.assertEqual((listed['rating'], listed['review_count']), (None, 0))

        self.play()
        self.review()
        self.assertEqual(client_for(self.customer).delete(self.url).status_code, 204)
        self.assertFalse(Review.objects.exists())
