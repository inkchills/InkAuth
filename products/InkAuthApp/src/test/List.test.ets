import localUnitTest from './LocalUnit.test';
import uriPathCandidatesTest from './UriPathCandidates.test';
import otpGeneratorTest from './OtpGenerator.test';

export default function testsuite() {
  localUnitTest();
  uriPathCandidatesTest();
  otpGeneratorTest();
}
