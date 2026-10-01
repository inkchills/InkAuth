import { describe, it, expect } from '@ohos/hypium';
import { HashAlgorithm } from '../main/ets/core/generator/HashAlgorithm';
import { Hotp } from '../main/ets/core/generator/Hotp';
import { Totp } from '../main/ets/core/generator/Totp';
import { SteamOtp } from '../main/ets/core/generator/SteamOtp';
import { MobileOtp } from '../main/ets/core/generator/MobileOtp';
import { YandexOtp } from '../main/ets/core/generator/YandexOtp';

/**
 * Vectors copied from stratumauth/app v1.6.2:
 * Stratum.Test/src/Generator/{Hotp,Totp,SteamOtp,MobileOtp,YandexOtp}Test.cs
 */
export default function otpGeneratorTest() {
  describe('Hotp', () => {
    it('matches RFC 4226 appendix D', 0, async () => {
      const hotp = new Hotp('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ', HashAlgorithm.Sha1, 6);
      const expected: Record<number, string> = {
        0: '755224',
        1: '287082',
        2: '359152',
        3: '969429',
        4: '338314',
        5: '254676',
        6: '287922',
        7: '162583',
        8: '399871',
        9: '520489'
      };
      const counters = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
      for (let i = 0; i < counters.length; i++) {
        const counter = counters[i];
        expect(await hotp.compute(counter)).assertEqual(expected[counter]);
      }
    });
  });

  describe('Totp', () => {
    const sha1Secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
    const sha256Secret = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZA====';
    const sha512Secret =
      'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQGEZDGNA=';

    it('matches RFC 6238 8-digit vectors', 0, async () => {
      const cases: Array<[number, string, HashAlgorithm, string]> = [
        [59, '94287082', HashAlgorithm.Sha1, sha1Secret],
        [59, '46119246', HashAlgorithm.Sha256, sha256Secret],
        [59, '90693936', HashAlgorithm.Sha512, sha512Secret],
        [1111111109, '07081804', HashAlgorithm.Sha1, sha1Secret],
        [1111111109, '68084774', HashAlgorithm.Sha256, sha256Secret],
        [1111111109, '25091201', HashAlgorithm.Sha512, sha512Secret],
        [1111111111, '14050471', HashAlgorithm.Sha1, sha1Secret],
        [1111111111, '67062674', HashAlgorithm.Sha256, sha256Secret],
        [1111111111, '99943326', HashAlgorithm.Sha512, sha512Secret],
        [1234567890, '89005924', HashAlgorithm.Sha1, sha1Secret],
        [1234567890, '91819424', HashAlgorithm.Sha256, sha256Secret],
        [1234567890, '93441116', HashAlgorithm.Sha512, sha512Secret],
        [2000000000, '69279037', HashAlgorithm.Sha1, sha1Secret],
        [2000000000, '90698825', HashAlgorithm.Sha256, sha256Secret],
        [2000000000, '38618901', HashAlgorithm.Sha512, sha512Secret],
        [20000000000, '65353130', HashAlgorithm.Sha1, sha1Secret],
        [20000000000, '77737706', HashAlgorithm.Sha256, sha256Secret],
        [20000000000, '47863826', HashAlgorithm.Sha512, sha512Secret]
      ];
      for (let i = 0; i < cases.length; i++) {
        const offset = cases[i][0];
        const expected = cases[i][1];
        const algorithm = cases[i][2];
        const secret = cases[i][3];
        const totp = new Totp(secret, 30, algorithm, 8);
        expect(await totp.compute(offset)).assertEqual(expected);
      }
    });
  });

  describe('SteamOtp', () => {
    // KeePassXC TestTotp.cpp vectors, same source as Stratum.Test
    it('matches KeePassXC steam vectors', 0, async () => {
      const steam = new SteamOtp('63BEDWCQZKTQWPESARIERL5DTTQFCJTK');
      expect(await steam.compute(1511200518)).assertEqual('FR8RV');
      expect(await steam.compute(1511200714)).assertEqual('9P3VP');
    });
  });

  describe('MobileOtp', () => {
    it('matches Stratum.Test MobileOtp vectors', 0, async () => {
      const motp = new MobileOtp('7ac61d4736f51a2b', '5555');
      expect(await motp.compute(0)).assertEqual('c42a26');
      expect(await motp.compute(1000000000)).assertEqual('4af383');
    });
  });

  describe('YandexOtp', () => {
    // https://github.com/norblik/KeeYaOtp vectors, same source as Stratum.Test
    it('matches KeeYaOtp vectors', 0, async () => {
      const cases: Array<[string, string, number, string]> = [
        ['LA2V6KMCGYMWWVEW64RNP3JA3IAAAAAAHTSG4HRZPI', '7586', 1581064020, 'oactmacq'],
        ['LA2V6KMCGYMWWVEW64RNP3JA3IAAAAAAHTSG4HRZPI', '7586', 1581090810, 'wemdwrix'],
        ['JBGSAU4G7IEZG6OY4UAXX62JU4AAAAAAHTSG4HXU3M', '5210481216086702', 1581091469, 'dfrpywob'],
        ['JBGSAU4G7IEZG6OY4UAXX62JU4AAAAAAHTSG4HXU3M', '5210481216086702', 1581093059, 'vunyprpd']
      ];
      for (let i = 0; i < cases.length; i++) {
        const yandex = new YandexOtp(cases[i][0], cases[i][1]);
        expect(await yandex.compute(cases[i][2])).assertEqual(cases[i][3]);
      }
    });
  });
}
