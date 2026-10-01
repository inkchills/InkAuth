import { describe, it, expect } from '@ohos/hypium';
import { UriPathCandidates } from '../main/ets/core/util/UriPathCandidates';

export default function uriPathCandidatesTest() {
  describe('UriPathCandidates', () => {
    it('puts original uri first', 0, () => {
      const out = UriPathCandidates.fromUri('file://docs/currentUser/Download/a.json');
      expect(out[0]).assertEqual('file://docs/currentUser/Download/a.json');
    });

    it('appends extra path when different from uri', 0, () => {
      const out = UriPathCandidates.fromUri(
        'file://docs/currentUser/Download/a.json',
        '/storage/Users/currentUser/Download/a.json'
      );
      expect(out.length).assertEqual(2);
      expect(out[1]).assertEqual('/storage/Users/currentUser/Download/a.json');
    });

    it('does not duplicate extra path when it equals uri', 0, () => {
      const uri = '/data/storage/el2/base/a.json';
      const out = UriPathCandidates.fromUri(uri, uri);
      expect(out.length).assertEqual(1);
    });

    it('strips query as a later candidate', 0, () => {
      const out = UriPathCandidates.fromUri('file://docs/currentUser/Download/a.json?offset=0');
      expect(out[0]).assertEqual('file://docs/currentUser/Download/a.json?offset=0');
      expect(out[out.length - 1]).assertEqual('file://docs/currentUser/Download/a.json');
    });

    it('ignores empty uri', 0, () => {
      const out = UriPathCandidates.fromUri('');
      expect(out.length).assertEqual(0);
    });

    it('joins folder uri and file name without double slash', 0, () => {
      expect(UriPathCandidates.joinFolder('file://docs/currentUser/Download', 'backup.html'))
        .assertEqual('file://docs/currentUser/Download/backup.html');
      expect(UriPathCandidates.joinFolder('file://docs/currentUser/Download/', 'backup.html'))
        .assertEqual('file://docs/currentUser/Download/backup.html');
    });
  });
}
