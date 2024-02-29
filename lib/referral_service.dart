import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get_ip_address/get_ip_address.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_strategy/url_strategy.dart';

const _kReferralLinksField = "referral_links";
const _kReferralLinkField = "referral_link";
const _kReferralIpField = "referral_ip";
const _kReferralIdField = "referral_id";
const _kReferralTypeField = "referral_type";

class ReferralInfo {
  final String? id;
  final String? ip;
  final String? link;
  final int? type;

  const ReferralInfo._({
    required this.id,
    required this.ip,
    required this.link,
    required this.type,
  });

  factory ReferralInfo.from(Map<String, dynamic>? source) {
    final id = source?[_kReferralIdField];
    final ip = source?[_kReferralIpField];
    final link = source?[_kReferralLinkField];
    final type = source?[_kReferralTypeField];
    return ReferralInfo._(
      id: id is String ? id : null,
      ip: ip is String ? ip : null,
      link: link is String ? link : null,
      type: type is int ? type : null,
    );
  }
}

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

  String? _code(String path) {
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

  Future<String> getLink(String id, [int type = 1]) {
    final link = _link(id);
    return _firestore.collection(_kReferralLinksField).doc(id).set(
      {
        _kReferralIdField: id,
        _kReferralLinkField: link,
        _kReferralTypeField: type,
      },
      SetOptions(merge: true),
    ).then((_) => link);
  }

  Future<ReferralInfo?> getInfoFromId(String id) async {
    return _firestore
        .collection(_kReferralLinksField)
        .doc(id)
        .get()
        .then((value) {
      if (value.exists) {
        final data = value.data();
        if (data != null) {
          return ReferralInfo.from(data);
        } else {
          return null;
        }
      } else {
        return null;
      }
    });
  }

  Future<ReferralInfo?> getInfoFromIP(String ip) async {
    return _firestore
        .collection(_kReferralLinksField)
        .where(_kReferralIpField, isEqualTo: ip)
        .get()
        .then((value) {
      if (value.docs.isNotEmpty) {
        final data = value.docs.firstOrNull?.data();
        if (data != null) {
          return ReferralInfo.from(data);
        } else {
          return null;
        }
      } else {
        return null;
      }
    });
  }

  Future<bool> isReferredIP(String ip) {
    return getInfoFromIP(ip).then((i) => i != null);
  }

  Future<bool> isReferredId(String id) async {
    return getInfoFromId(id).then((value) => value != null);
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
    final value = params[queryField];
    if (value != null && value.isNotEmpty) {
      execute(value);
    }
  }

  void executeByUri(Uri uri) {
    final value = uri.queryParameters[queryField];
    if (value != null && value.isNotEmpty) {
      execute(value);
    }
  }

  void executeByPath(String path) {
    final value = _code(path);
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
