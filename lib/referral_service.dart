import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get_ip_address/get_ip_address.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_strategy/url_strategy.dart';

const _kReferralLinksField = "referral_links";
const _kReferralLinkField = "referral_link";
const _kReferralIpField = "referral_ip";
const _kReferredIdField = "referrer_id";

class ReferralLinkService {
  final String baseUrl;
  final String endPoint;
  final String queryField;
  final String? appstoreLink;
  final String? playStoreLink;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ReferralLinkService._({
    required this.baseUrl,
    required this.endPoint,
    required this.queryField,
    required this.appstoreLink,
    required this.playStoreLink,
  });

  static ReferralLinkService? _i;

  static ReferralLinkService init({
    String baseUrl = "https://dynamic-link-bd.web.app",
    String endPoint = "referral",
    String queryField = "ref",
    String? appstoreLink,
    String? playStoreLink,
  }) {
    setPathUrlStrategy();
    return _i ??= ReferralLinkService._(
      baseUrl: baseUrl,
      endPoint: endPoint,
      queryField: queryField,
      appstoreLink: appstoreLink,
      playStoreLink: playStoreLink,
    );
  }

  static ReferralLinkService? get instance => _i;

  String _path(String path) {
    if (path.startsWith("/")) {
      return "$baseUrl$path";
    } else {
      return "$baseUrl/$path";
    }
  }

  String _link(String id) => "$baseUrl/$endPoint?$queryField=$id";

  String? getCode(Map<String, String> params) => params[queryField];

  String? getCodeFromPath(String path) {
    final uri = Uri.tryParse(_path(path));
    if (uri != null &&
        uri.pathSegments.isNotEmpty &&
        uri.pathSegments.last == endPoint &&
        uri.queryParameters.containsKey(queryField)) {
      return uri.queryParameters[queryField];
    } else {
      return null;
    }
  }

  Future<String?> getCodeFromLink(String link) async {
    final query = await _firestore
        .collection(_kReferralLinksField)
        .where(_kReferralLinkField, isEqualTo: link)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.id;
    } else {
      return null;
    }
  }

  Future<String> getLink(String id) {
    final link = _link(id);
    return _firestore.collection(_kReferralLinksField).doc(id).set(
      {
        _kReferredIdField: id,
        _kReferralLinkField: link,
      },
      SetOptions(merge: true),
    ).then((_) => link);
  }

  Future<Map<String, dynamic>?> getInfo(String id) async {
    return _firestore
        .collection(_kReferralLinksField)
        .doc(id)
        .get()
        .then((value) {
      if (value.exists) {
        return value.data();
      } else {
        return null;
      }
    });
  }

  Future<bool> isReferredIP(String ip) async {
    final query = await _firestore
        .collection(_kReferralLinksField)
        .where(_kReferralIpField, isEqualTo: ip)
        .get();
    return query.docs.isNotEmpty;
  }

  Future<bool> isReferredId(String id) async {
    final query = await _firestore
        .collection(_kReferralLinksField)
        .where(_kReferredIdField, isEqualTo: id)
        .get();
    return query.docs.isNotEmpty;
  }

  Future<void> storeIP({required String id, required String ip}) async {
    await _firestore.collection(_kReferralLinksField).doc(id).set(
      {
        _kReferralIpField: ip,
      },
      SetOptions(merge: true),
    );
  }

  void execute(String? code) async {
    if (code != null) {
      final ip = await IpAddress().getIp();
      await storeIP(id: code, ip: ip);
    }
    if (kIsWeb) {
      final launcher = playStoreLink;
      if (launcher != null && launcher.isNotEmpty) {
        _launchUrl(launcher);
      }
    } else if (Platform.isAndroid) {
      final launcher = playStoreLink;
      if (launcher != null && launcher.isNotEmpty) {
        _launchUrl(launcher);
      }
    } else if (Platform.isIOS || Platform.isMacOS) {
      final launcher = appstoreLink;
      if (launcher != null && launcher.isNotEmpty) {
        _launchUrl(launcher);
      }
    }
  }

  void executeByParams(Map<String, String> params) {
    final value = getCode(params);
    if (value != null && value.isNotEmpty) {
      execute(value);
    }
  }

  void executeByUri(Uri uri) {
    final value = getCode(uri.queryParameters);
    if (value != null && value.isNotEmpty) {
      execute(value);
    }
  }

  void executeByPath(String path) {
    final value = getCodeFromPath(path);
    if (value != null && value.isNotEmpty) {
      execute(value);
    }
  }

  Future<void> _launchUrl(String link) async {
    final Uri url = Uri.parse(link);
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }
}
