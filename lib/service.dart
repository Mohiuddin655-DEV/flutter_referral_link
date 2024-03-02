import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:math' show Random;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get_ip_address/get_ip_address.dart';
import 'package:url_launcher/url_launcher.dart';

const kUsers = "users";
const kReferrals = "referrals";

extension _ShowLogsExtension on bool? {
  bool l(dynamic msg) {
    if (this ?? true) log("$msg");
    return true;
  }
}

class ReferralService {
  final String baseUrl;
  final String endPoint;
  final String queryField;
  final String? appstoreLink;
  final String? playStoreLink;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ReferralService._({
    required this.baseUrl,
    required this.endPoint,
    required this.queryField,
    required this.appstoreLink,
    required this.playStoreLink,
  });

  static ReferralService? _i;

  static ReferralService init({
    String baseUrl = "https://dynamic-link-bd.web.app",
    String endPoint = "referral",
    String queryField = "ref",
    String? appstoreLink,
    String? playStoreLink,
  }) {
    return _i ??= ReferralService._(
      baseUrl: baseUrl,
      endPoint: endPoint,
      queryField: queryField,
      appstoreLink: appstoreLink,
      playStoreLink: playStoreLink,
    );
  }

  static ReferralService get i {
    if (_i != null) {
      return _i!;
    } else {
      throw UnimplementedError(
        "Please initialize ReferralService in main function",
      );
    }
  }

  /// LINK WAYS OPERATION LOGICS

  String? _idFromPath(String path) {
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

  String _link(String code) => "$baseUrl/$endPoint?$queryField=$code";

  String _path(String path) {
    if (path.startsWith("/")) {
      return "$baseUrl$path";
    } else {
      return "$baseUrl/$path";
    }
  }

  Future<String?> getIp() {
    return IpAddress().getIp().then((v) => v is String ? v : null);
  }

  Future<ReferralModel?> getReferralFromIP([String? ip]) async {
    ip ??= await getIp().then((value) => value ?? "");
    return _firestore
        .collection(kReferrals)
        .where(ReferralKeys.i.ip, isEqualTo: ip)
        .get()
        .then((value) {
      if (value.docs.isNotEmpty) {
        final data = value.docs.firstOrNull?.data();
        if (data != null) {
          return ReferralModel.from(data);
        } else {
          return null;
        }
      } else {
        return null;
      }
    });
  }

  Future<bool> isReferredIP(String ip) {
    return getReferralFromIP(ip).then((i) => i != null);
  }

  Future<void> _storeIP({required String id, required String ip}) async {
    await _firestore.collection(kReferrals).doc(id).update({
      ReferralKeys.i.ip: ip,
    });
  }

  void storeIp(String? code) async {
    if (code != null) {
      final ip = await getIp();
      if (ip != null && ip.isNotEmpty) {
        await _storeIP(id: code, ip: ip);
      }
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

  void storeIpByParams(Map<String, String> params) {
    final value = params[queryField];
    if (value != null && value.isNotEmpty) {
      storeIp(value);
    }
  }

  void storeIpByPath(String path) {
    final value = _idFromPath(path);
    if (value != null && value.isNotEmpty) {
      storeIp(value);
    }
  }

  void storeIpByUri(Uri uri) => storeIpByParams(uri.queryParameters);

  Future<void> _launchUrl(String link) async {
    final Uri url = Uri.parse(link);
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  /// APPLY WAYS OPERATION LOGICS
  String _generateCode({int length = 8}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(
      List.generate(length, (index) {
        return chars.codeUnitAt(Random().nextInt(chars.length));
      }),
    );
  }

  Future<bool> _apply({
    required UserModel? user,
    String? code,
    bool? log,
  }) async {
    final uid = user?.id;
    final xInvalidUid = uid == null || uid.isEmpty;
    final xInvalidUser = user == null || xInvalidUid || user.isRedeemed;
    log.l("_apply (invalidUser: $xInvalidUser)");
    if (xInvalidUser) return Future.value(false);
    ReferralModel? referral;
    if (code == null || code.isEmpty) {
      referral = await getReferralFromIP();
    } else {
      log.l("getReferral(id: $code)");
      referral = await getReferral(code);
    }
    final isInvalidCode = referral == null || (referral.id ?? "").isEmpty;
    final isInvalidUid = user.isReferral(referral?.id);
    final isMember = referral?.isMember(uid) ?? false;
    log.l(
      "checking referral(isInvalidCode: $isInvalidCode, isInvalidUser: $isInvalidUid, isMember: $isMember)",
    );
    if (!isInvalidCode && !isInvalidUid && !isMember) {
      log.l("updateUser(current.id : $uid)");
      final userDuration = getRemainingDuration(
        createdAt: user.rewardCreatedAt,
        days: user.rewardDuration,
      );

      final currentUDays = userDuration.inDays + Rewards.x1.duration;

      return _updateUser(uid, {
        UserKeys.i.redeemed: true,
        UserKeys.i.redeemedCode: referral.id,
        UserKeys.i.reward: Rewards.x1.category,
        UserKeys.i.rewardDuration: currentUDays,
        UserKeys.i.rewardCreatedAt: Rewards.x1.createdAt,
        UserKeys.i.rewardExpireAt: Rewards.x1.expireAt,
      }).then((_) {
        log.l("updateUser(referrer.id : ${referral?.uid})");
        return _getUser(referral?.uid).then((referrer) {
          if (referrer == null) return Future.value(false);
          final referrerDuration = getRemainingDuration(
            createdAt: referrer.rewardCreatedAt,
            days: referrer.rewardDuration,
          );
          final currentRDays = referrerDuration.inDays + Rewards.x2.duration;
          return _updateUser(referral?.uid, {
            UserKeys.i.reward: Rewards.x2.category,
            UserKeys.i.rewardDuration: currentRDays,
            UserKeys.i.rewardCreatedAt: Rewards.x2.createdAt,
            UserKeys.i.rewardExpireAt: Rewards.x2.expireAt,
          }).then((_) {
            log.l("updateReferral(referral.id : ${referral?.id})");
            return _updateReferral(referral?.id, {
              ReferralKeys.i.members: FieldValue.arrayUnion([uid]),
            }).then((_) => log.l("done"));
          });
        });
      });
    } else {
      return false;
    }
  }

  Future<bool> createReferral(String? id, String? uid) {
    if (id == null || uid == null || id.isEmpty || uid.isEmpty) {
      return Future.value(false);
    }
    final data = ReferralModel(id: id, uid: uid);
    return FirebaseFirestore.instance
        .collection(kReferrals)
        .doc(data.id)
        .set(data.source, SetOptions(merge: true))
        .then((value) => true);
  }

  Future<bool> createUser(UserModel user, {bool? log}) {
    log.l("createUser(user.source: ${user.source})");
    if (user.source.isEmpty) return Future.value(false);

    final currentUid = user.noneUid;
    final redeemCode = user.redeemedCode;
    final referralCode = _generateCode(length: 6);

    final current = user.copy(
      id: currentUid,
      referralCode: referralCode,
      redeemClear: true,
    );
    return FirebaseFirestore.instance
        .collection(kUsers)
        .doc(currentUid)
        .set(current.source, SetOptions(merge: true))
        .then((_) => createReferral(referralCode, currentUid))
        .then((_) => _apply(code: redeemCode, user: current));
  }

  Future<bool> redeemIP(String? uid, {bool? log}) {
    log.l("addRedeem(uid: $uid)");
    if (uid == null || uid.isEmpty) {
      return Future.value(false);
    }
    log.l("getUser(current.id: $uid)");
    return _getUser(uid).then((user) {
      log.l("checking current user (isRedeemed: ${user?.isRedeemed})");
      if (user != null && !user.isRedeemed) {
        return _apply(user: user, log: log);
      }
      return false;
    });
  }

  Future<bool> redeemCode(String? uid, String? code, {bool? log}) {
    log.l("addRedeem(uid: $uid, code: $code)");
    if (uid == null || code == null || uid.isEmpty || code.isEmpty) {
      return Future.value(false);
    }
    log.l("getUser(current.id: $uid)");
    return _getUser(uid).then((user) {
      log.l("checking current user (isRedeemed: ${user?.isRedeemed})");
      if (user != null && !user.isRedeemed) {
        return _apply(user: user, code: code);
      }
      return false;
    });
  }

  Future<String> referCode(String? uid, {int length = 8}) async {
    return _getUser(uid).then((value) {
      final code = value?.referralCode ?? "";
      if (code.isNotEmpty) return _link(code);
      final current = _generateCode(length: length);
      final link = _link(current);
      return createReferral(current, uid).then((_) {
        return _updateUser(uid, {
          UserKeys.i.referralCode: current,
        }).then((_) => link);
      });
    });
  }

  Future<UserModel?> referrer({required String? code, bool? log}) {
    final xInvalidCode = code == null || code.isEmpty;
    log.l("_apply (inValidCode: $xInvalidCode)");
    if (xInvalidCode) return Future.value(null);
    log.l("getReferral(id: $code)");
    return getReferral(code).then((value) => _getUser(value?.uid));
  }

  Future<ReferralModel?> getReferral(String? id) {
    if (id == null || id.isEmpty) return Future.value(null);
    return FirebaseFirestore.instance
        .collection(kReferrals)
        .doc(id)
        .get()
        .then((value) {
      final data = value.data();
      if (data != null) {
        return ReferralModel.from(data);
      } else {
        return null;
      }
    });
  }

  Duration getRemainingDuration({
    required int? createdAt,
    required int? days,
  }) {
    if (createdAt != null && days != null && days > 0) {
      final creationDate = DateTime.fromMillisecondsSinceEpoch(createdAt);
      final expireDate = creationDate.add(Duration(days: days));
      final currentDate = DateTime.now();
      final remainingDuration = expireDate.difference(currentDate);
      return remainingDuration;
    }

    return Duration.zero;
  }

  Future<UserModel?> _getUser(String? id) {
    if (id == null || id.isEmpty) return Future.value(null);
    return FirebaseFirestore.instance
        .collection(kUsers)
        .doc(id)
        .get()
        .then((value) {
      final data = value.data();
      if (data != null) {
        return UserModel.from(data);
      } else {
        return null;
      }
    });
  }

  Future<bool> isEligible(String? uid, {int? days}) {
    if (uid == null || uid.isEmpty) return Future.value(false);
    return _getUser(uid).then((user) {
      return isEligibleWith(
        createdAt: user?.rewardCreatedAt,
        days: days ?? user?.rewardDuration,
      );
    });
  }

  bool isEligibleWith({required int? createdAt, required int? days}) {
    if (createdAt != null && days != null && days > 0) {
      final creationDate = DateTime.fromMillisecondsSinceEpoch(createdAt);
      final currentDate = DateTime.now();
      final endDate = creationDate.add(Duration(days: days));
      return currentDate.isBefore(endDate);
    }
    return false;
  }

  Future<bool> updateDuration({
    required String? uid,
    bool allow = false,
    int changingAmount = -1,
    bool? log,
  }) {
    final xInvalidUid = uid == null || uid.isEmpty;
    final xInvalidAmount = changingAmount == 0;
    log.l(
      "_change(allow: $allow, inValidUser: $xInvalidUid invalidAmount: $xInvalidAmount)",
    );
    if (xInvalidUid || xInvalidAmount || !allow) return Future.value(false);

    log.l("updateUser(uid : $uid, changingAmount : $changingAmount)");
    return _updateUser(uid, {
      UserKeys.i.rewardDuration: FieldValue.increment(changingAmount),
    }).then((_) => log.l("done"));
  }

  Future<bool> updateExpiry({
    required String? uid,
    required DateTime expiry,
    bool? log,
  }) {
    final xInvalidUid = uid == null || uid.isEmpty;

    if (xInvalidUid) return Future.value(false);

    log.l("updateUser(uid : $uid)");
    return _updateUser(uid, {
      UserKeys.i.rewardExpireAt: expiry.millisecondsSinceEpoch,
    }).then((_) => log.l("done"));
  }

  Future<bool> _updateReferral(String? id, Map<String, dynamic>? data) {
    if (id == null || data == null || id.isEmpty || data.isEmpty) {
      return Future.value(false);
    }
    return FirebaseFirestore.instance
        .collection(kReferrals)
        .doc(id)
        .update(data)
        .then((_) => true);
  }

  Future<bool> _updateUser(String? id, Map<String, dynamic>? data) {
    if (id == null || data == null || id.isEmpty || data.isEmpty) {
      return Future.value(false);
    }
    return FirebaseFirestore.instance
        .collection(kUsers)
        .doc(id)
        .update(data)
        .then((_) => true);
  }
}

enum Rewards {
  x1(category: 1, duration: 3),
  x2(category: 2, duration: 7),
  x3(category: 3, duration: 15);

  final int category;
  final int duration;

  const Rewards({
    required this.category,
    required this.duration,
  });

  bool get isX1 => this == x1;

  bool get isX2 => this == x2;

  bool get isX3 => this == x3;

  int get createdAt => DateTime.now().millisecondsSinceEpoch;

  int get expireAt {
    final now = DateTime.now();
    if (isX1) {
      return now.add(Duration(days: x1.duration)).millisecondsSinceEpoch;
    } else if (isX2) {
      return now.add(Duration(days: x2.duration)).millisecondsSinceEpoch;
    } else {
      return now.add(Duration(days: x3.duration)).millisecondsSinceEpoch;
    }
  }
}

class ReferralKeys {
  final id = "id";
  final ip = "ip";
  final uid = "uid";
  final members = "members";

  const ReferralKeys._();

  static ReferralKeys? _i;

  static ReferralKeys get i => _i ??= const ReferralKeys._();
}

class ReferralModel {
  final String? id;
  final String? ip;
  final String? uid;
  final List<String>? members;

  const ReferralModel({
    this.id,
    this.ip,
    this.uid,
    this.members,
  });

  bool isMember(String? uid) => (members ?? []).contains(uid);

  factory ReferralModel.from(Map<String, dynamic> source) {
    final id = source[ReferralKeys.i.id];
    final ip = source[ReferralKeys.i.ip];
    final uid = source[ReferralKeys.i.uid];
    final members = source[ReferralKeys.i.members];
    return ReferralModel(
      id: id is String ? id : null,
      ip: ip is String ? ip : null,
      uid: uid is String ? uid : null,
      members: members is List ? members.map((e) => "$e").toList() : null,
    );
  }

  ReferralModel copy({
    String? id,
    String? ip,
    String? uid,
    List<String>? members,
  }) {
    return ReferralModel(
      id: id ?? this.id,
      ip: ip ?? this.ip,
      uid: uid ?? this.uid,
      members: members ?? this.members,
    );
  }

  Map<String, dynamic> get source {
    return {
      ReferralKeys.i.id: id,
      ReferralKeys.i.ip: ip,
      ReferralKeys.i.uid: uid,
      ReferralKeys.i.members: members?.map((e) => e.toString()),
    };
  }
}

class UserKeys {
  final id = "id";
  final redeemed = "redeemed";
  final redeemedCode = "redeemed_code";
  final referralCode = "referral_code";
  final reward = "reward";
  final rewardDuration = "reward_duration";
  final rewardCreatedAt = "reward_created_at";
  final rewardExpireAt = "reward_expire_at";

  const UserKeys._();

  static UserKeys? _i;

  static UserKeys get i => _i ??= const UserKeys._();
}

class UserModel {
  final String? id;
  final bool? redeemed;
  final String? redeemedCode;
  final String? referralCode;
  final int? reward;
  final int? rewardDuration;
  final int? rewardCreatedAt;
  final int? rewardExpireAt;

  String get noneUid {
    return id ?? DateTime.timestamp().millisecondsSinceEpoch.toString();
  }

  bool get isCurrentUid => id == "1706388765933";

  bool get isEligible {
    return ReferralService.i.isEligibleWith(
      createdAt: rewardCreatedAt,
      days: rewardDuration,
    );
  }

  bool get isRedeemed => redeemed ?? false;

  const UserModel({
    this.id,
    this.redeemed,
    this.redeemedCode,
    this.referralCode,
    this.reward,
    this.rewardDuration,
    this.rewardCreatedAt,
    this.rewardExpireAt,
  });

  bool isReferral(String? code) => referralCode == code;

  factory UserModel.from(Map<String, dynamic> source) {
    final id = source[UserKeys.i.id];
    final redeemed = source[UserKeys.i.redeemed];
    final redeemedCode = source[UserKeys.i.redeemedCode];
    final referralCode = source[UserKeys.i.referralCode];
    final reward = source[UserKeys.i.reward];
    final rewardDuration = source[UserKeys.i.rewardDuration];
    final rewardCreatedAt = source[UserKeys.i.rewardCreatedAt];
    final rewardExpireAt = source[UserKeys.i.rewardExpireAt];
    return UserModel(
      id: id is String ? id : null,
      redeemed: redeemed is bool ? redeemed : null,
      redeemedCode: redeemedCode is String ? redeemedCode : null,
      referralCode: referralCode is String ? referralCode : null,
      reward: reward is int ? reward : null,
      rewardDuration: rewardDuration is int ? rewardDuration : null,
      rewardCreatedAt: rewardCreatedAt is int ? rewardCreatedAt : null,
      rewardExpireAt: rewardExpireAt is int ? rewardExpireAt : null,
    );
  }

  UserModel copy({
    String? id,
    bool? redeemed,
    String? redeemedCode,
    bool redeemClear = false,
    String? referralCode,
    int? reward,
    int? rewardDuration,
    int? rewardCreatedAt,
    int? rewardExpireAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      redeemed: redeemed ?? this.redeemed,
      referralCode: referralCode ?? this.referralCode,
      redeemedCode: redeemClear ? null : redeemedCode ?? this.redeemedCode,
      reward: reward ?? this.reward,
      rewardDuration: rewardDuration ?? this.rewardDuration,
      rewardCreatedAt: rewardCreatedAt ?? this.rewardCreatedAt,
      rewardExpireAt: rewardExpireAt ?? this.rewardExpireAt,
    );
  }

  Map<String, dynamic> get source {
    return {
      UserKeys.i.id: id,
      UserKeys.i.redeemed: redeemed,
      UserKeys.i.redeemedCode: redeemedCode,
      UserKeys.i.referralCode: referralCode,
      UserKeys.i.reward: reward,
      UserKeys.i.rewardDuration: rewardDuration,
      UserKeys.i.rewardCreatedAt: rewardCreatedAt,
      UserKeys.i.rewardExpireAt: rewardExpireAt,
    };
  }
}
