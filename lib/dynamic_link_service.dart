import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/cupertino.dart';

class FirebaseDynamicLinksService {
  static FirebaseDynamicLinksService? _i;

  static FirebaseDynamicLinksService get i {
    return _i ??= FirebaseDynamicLinksService();
  }

  Future<Uri> createDynamicLink(String code) async {
    final params = DynamicLinkParameters(
      link: Uri.parse(
        "https://flutterreferrallink.page.link.com/referral?code=$code",
      ),
      uriPrefix: "https://flutterreferrallink.page.link",
      androidParameters:  AndroidParameters(
        packageName: "com.example.flutter_referral_link",
        fallbackUrl: Uri.parse("https://dynamic-link-bd.web.app/"),
      ),
      iosParameters: const IOSParameters(
        bundleId: "com.example.flutterReferralLink",
      ),
    );
    final link = await FirebaseDynamicLinks.instance.buildShortLink(params);
    debugPrint(link.shortUrl.toString());
    return link.shortUrl;
  }
}
