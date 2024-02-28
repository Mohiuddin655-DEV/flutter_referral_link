import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/cupertino.dart';

class FirebaseDynamicLinksService {
  static FirebaseDynamicLinksService? _i;

  static FirebaseDynamicLinksService get i {
    return _i ??= FirebaseDynamicLinksService();
  }

  Future<Uri> createDynamicLink() async {
    final params = DynamicLinkParameters(
      link: Uri.parse("https://flutterreferrallink.page.link.com"),
      uriPrefix: "https://flutterreferrallink.page.link",
      androidParameters:
          const AndroidParameters(packageName: "com.example.flutter_referral_link"),
      iosParameters: const IOSParameters(bundleId: "com.example.flutterReferralLink"),
    );
    final dynamicLink = await FirebaseDynamicLinks.instance.buildShortLink(params);
    debugPrint(dynamicLink.previewLink.toString());
    return dynamicLink.shortUrl;
  }
}
