import unittest
from type6_monitor_adapter import extract_type6_status, type6_alarm_transition


def sample(value):
    return {'components': {'main': {
        'buildbook37604.type6communication': {
            'linkState': {'value': value},
            'minutesWithoutRx': {'value': 60},
            'lastReceived': {'value': '2026-10-20T00:00:00Z'},
            'timeoutMinutes': {'value': 60},
        }
    }}}


class AdapterTests(unittest.TestCase):
    def test_normal(self):
        self.assertEqual(extract_type6_status(sample('normal'), {'state': 'ONLINE'})['monitor_status'], 'online')
    def test_suspect_cloud_online(self):
        self.assertEqual(extract_type6_status(sample('suspect'), {'state': 'ONLINE'})['monitor_status'], 'caution')
    def test_offline_precedence(self):
        self.assertEqual(extract_type6_status(sample('suspect'), {'state': 'OFFLINE'})['monitor_status'], 'offline')
    def test_case_normalization(self):
        status = sample('normal')
        main = status['components']['main']
        main['buildbook37604.type6Communication'] = main.pop('buildbook37604.type6communication')
        self.assertEqual(extract_type6_status(status, {'state': 'ONLINE'})['monitor_status'], 'online')
    def test_other_device(self):
        self.assertIsNone(extract_type6_status({'components': {'main': {'battery': {'battery': {'value': 80}}}}}))
    def test_alert_dedup(self):
        prev = extract_type6_status(sample('normal'), {'state': 'ONLINE'})
        cur = extract_type6_status(sample('suspect'), {'state': 'ONLINE'})
        self.assertEqual(type6_alarm_transition(prev, cur)['event'], 'type6_link_suspect')
        self.assertIsNone(type6_alarm_transition(cur, cur))
        recover = extract_type6_status(sample('normal'), {'state': 'ONLINE'})
        self.assertEqual(type6_alarm_transition(cur, recover)['event'], 'type6_link_recovered')
        offline = extract_type6_status(sample('suspect'), {'state': 'OFFLINE'})
        self.assertIsNone(type6_alarm_transition(prev, offline))


if __name__ == '__main__':
    unittest.main()
