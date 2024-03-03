import 'dart:async';
import 'dart:developer';
import 'dart:math' show Random;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get_ip_address/get_ip_address.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_strategy/url_strategy.dart';

const kUsers = "users";
const kReferrals = "referrals";
const kMembers = "members";

class ReferralService {
  final String baseUrl;
  final String endPoint;
  final String queryField;
  final String? appstoreLink;
  final String? playStoreLink;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _x1 = FirebaseFirestore.instance.collection(kReferrals);

  ReferralService._({
    required this.baseUrl,
    required this.endPoint,
    required this.queryField,
    required this.appstoreLink,
    required this.playStoreLink,
  });

  static ReferralService? _i;

  static ReferralService init({
    bool resolveUrlStrategy = false,
    required String baseUrl,
    String endPoint = "referral",
    String queryField = "ref",
    String? appstoreLink,
    String? playStoreLink,
  }) {
    if (resolveUrlStrategy) {
      setPathUrlStrategy();
    }
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

  /// LINK GENERATOR
  ///
  String _generateLink(String code) => "$baseUrl/$endPoint?$queryField=$code";

  String _generateCode({int length = 8}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(
      List.generate(length, (index) {
        return chars.codeUnitAt(Random().nextInt(chars.length));
      }),
    );
  }

  Future<String> generateCode({
    String? uid,
    int plan = 1,
  }) async {
    return _fetch(uid).then((value) {
      final code = value?.referralCode ?? "";
      if (code.isNotEmpty) {
        return _updateReferral(code, {
          ReferralKeys.i.installs: null,
          ReferralKeys.i.plan: plan,
        }).then((_) {
          return _update(uid, {
            UserKeys.i.referralExpired: false,
          }).then((_) => _generateLink(code));
        });
      } else {
        final current = _generateCode();
        final link = _generateLink(current);
        return _createReferral(
          id: current,
          uid: uid,
          plan: plan,
        ).then((_) {
          return _update(uid, {
            UserKeys.i.referralCode: current,
            UserKeys.i.referralExpired: false,
          }).then((_) => link);
        });
      }
    });
  }

  Future<bool> _createReferral({
    String? id,
    String? uid,
    int plan = 1,
  }) {
    if (id == null || uid == null || id.isEmpty || uid.isEmpty || plan < 1) {
      return Future.value(false);
    }
    return FirebaseFirestore.instance.collection(kReferrals).doc(id).set({
      ReferralKeys.i.id: id,
      ReferralKeys.i.referrerId: uid,
      ReferralKeys.i.plan: plan,
    }).then((_) => true);
  }

  Future<bool> _updateReferral(String? id, Map<String, dynamic>? data) {
    if (id == null || data == null || id.isEmpty || data.isEmpty) {
      return Future.value(false);
    }
    return _x1.doc(id).update(data).then((_) => true);
  }

  Future<UserModel?> _fetch(String? uid) {
    if (uid == null || uid.isEmpty) return Future.value(null);
    return FirebaseFirestore.instance
        .collection(kUsers)
        .doc(uid)
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

  Future<bool> _update(String? id, Map<String, dynamic>? data) {
    if (id == null || data == null || id.isEmpty || data.isEmpty) {
      return Future.value(false);
    }
    return FirebaseFirestore.instance
        .collection(kUsers)
        .doc(id)
        .update(data)
        .then((_) => true);
  }

  /// IP TAKER
  ///

  Future<String?> get _ip {
    return IpAddress().getIp().then((v) => v is String ? v : null);
  }

  Future<void> _launchUrl(String link) async {
    final Uri url = Uri.parse(link);
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  void storeIp(String? code) async {
    if (code != null) {
      final ip = await _ip;
      if (ip != null && ip.isNotEmpty) {
        await _firestore.collection(kReferrals).doc(code).update({
          ReferralKeys.i.ips: FieldValue.arrayUnion([ip]),
        });
      }
    }
    final tp = defaultTargetPlatform;

    log("TARGET_PLATFORM: $tp");
    if (tp == TargetPlatform.android) {
      final launcher = playStoreLink;
      if (launcher != null && launcher.isNotEmpty) {
        _launchUrl(launcher);
      }
    } else if (tp == TargetPlatform.iOS || tp == TargetPlatform.macOS) {
      final launcher = appstoreLink;
      if (launcher != null && launcher.isNotEmpty) {
        _launchUrl(launcher);
      }
    }
  }

  void storeIpByPath(String path) {
    final regex = RegExp('$queryField=([^&]+)');
    final match = regex.firstMatch(path);
    final code = match?.group(1);
    if (code != null && code.isNotEmpty) {
      storeIp(code);
    }
  }

  /// MEMBERSHIP
  ///

  Future<Referral?> get _referral async {
    final ip = await _ip.then((value) => value ?? "");
    return _x1.where(ReferralKeys.i.ips, arrayContains: ip).get().then((v) {
      if (v.docs.isNotEmpty) {
        final data = v.docs.firstOrNull?.data();
        if (data != null) {
          return Referral.from(data);
        } else {
          return null;
        }
      } else {
        return null;
      }
    });
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

  Future<bool> _apply(UserModel user) async {
    final uid = user.id;
    final xInvalidUid = uid == null || uid.isEmpty;
    final xInvalidUser = xInvalidUid || user.isRedeemed;
    if (xInvalidUser) return Future.value(false);
    final referral = await _referral;
    final ip = await _ip;
    final isInvalidCode = referral == null || (referral.id ?? "").isEmpty;
    final isInvalidUid = user.isReferral(referral?.id);
    final isMember = referral?.isMember(uid) ?? false;
    if (!isInvalidCode && !isInvalidUid && !isMember) {
      return _update(uid, {
        UserKeys.i.redeemed: true,
        UserKeys.i.redeemedCode: referral.id,
        UserKeys.i.reward: Rewards.x1.category,
        UserKeys.i.rewardDuration: Rewards.x1.duration,
        UserKeys.i.rewardCreatedAt: Rewards.x1.createdAt,
        UserKeys.i.rewardExpireAt: Rewards.x1.expireAt,
      }).then((_) {
        return _getUser(referral.referrerId).then((referrer) {
          if (referrer == null) return Future.value(false);
          final reward = Rewards.from(referral.installs?.length ?? 0);
          final isExpired = referrer.isReferralExpired;
          if (isExpired) {
            return _updateReferral(referral.id, {
              ReferralKeys.i.ips: FieldValue.arrayRemove([ip]),
              ReferralKeys.i.members: FieldValue.arrayUnion([uid]),
            });
          } else {
            final isCurrentPlan = reward.category == referral.plan;
            return _update(referral.referrerId, {
              if (isCurrentPlan) UserKeys.i.reward: reward.category,
              if (isCurrentPlan) UserKeys.i.rewardDuration: reward.duration,
              if (isCurrentPlan) UserKeys.i.rewardCreatedAt: reward.createdAt,
              if (isCurrentPlan) UserKeys.i.rewardExpireAt: reward.expireAt,
              UserKeys.i.referralExpired: isCurrentPlan,
            }).then((_) {
              return _updateReferral(referral.id, {
                ReferralKeys.i.ips: FieldValue.arrayRemove([ip]),
                ReferralKeys.i.installs: FieldValue.arrayUnion([uid]),
                ReferralKeys.i.members: FieldValue.arrayUnion([uid]),
              });
            });
          }
        });
      });
    } else {
      return false;
    }
  }

  Future<bool> redeem(String? uid) {
    if (uid == null || uid.isEmpty) return Future.value(false);
    return _getUser(uid).then((user) {
      if (user != null && !user.isRedeemed) {
        return _apply(user);
      }
      return false;
    });
  }
}

enum Rewards {
  x1(category: 1, duration: 7),
  x2(category: 2, duration: 30),
  x3(category: 3, duration: 120);

  final int category;
  final int duration;

  const Rewards({
    required this.category,
    required this.duration,
  });

  bool get isX1 => this == x1;

  bool get isX2 => this == x2;

  bool get isX3 => this == x3;

  factory Rewards.from(int value) {
    value = value + 1;
    if (value == 4) {
      return Rewards.x2;
    } else if (value == 12) {
      return Rewards.x3;
    } else {
      return Rewards.x1;
    }
  }

  int get createdAt =>
      DateTime
          .now()
          .millisecondsSinceEpoch;

  int get expireAt {
    final now = DateTime.now();
    if (isX1) {
      return now
          .add(Duration(days: x1.duration))
          .millisecondsSinceEpoch;
    } else if (isX2) {
      return now
          .add(Duration(days: x2.duration))
          .millisecondsSinceEpoch;
    } else {
      return now
          .add(Duration(days: x3.duration))
          .millisecondsSinceEpoch;
    }
  }
}

class ReferralKeys {
  final id = "id";
  final referrerId = "referrer_id";
  final plan = "plan";
  final ips = "ips";
  final installs = "installs";
  final members = "members";

  const ReferralKeys._();

  static ReferralKeys? _i;

  static ReferralKeys get i => _i ??= const ReferralKeys._();
}

class Referral {
  final String? id;
  final String? referrerId;
  final int? plan;
  final List<String>? installs;
  final List<String>? ips;
  final List<String>? members;

  const Referral({
    this.id,
    this.referrerId,
    this.plan,
    this.installs,
    this.ips,
    this.members,
  });

  bool isIp(String? ip) => (ips ?? []).contains(ip);

  bool isMember(String? uid) => (members ?? []).contains(uid);

  factory Referral.from(Map<String, dynamic> source) {
    final id = source[ReferralKeys.i.id];
    final uid = source[ReferralKeys.i.referrerId];
    final plan = source[ReferralKeys.i.plan];
    final installs = source[ReferralKeys.i.installs];
    final ips = source[ReferralKeys.i.ips];
    final members = source[ReferralKeys.i.members];
    return Referral(
      id: id is String ? id : null,
      referrerId: uid is String ? uid : null,
      plan: plan is int ? plan : null,
      installs: installs is List ? installs.map((e) => "$e").toList() : null,
      ips: ips is List ? ips.map((e) => "$e").toList() : null,
      members: members is List ? members.map((e) => "$e").toList() : null,
    );
  }
}

class UserKeys {
  final id = "id";
  final redeemed = "redeemed";
  final redeemedCode = "redeemed_code";
  final referralCode = "referral_code";
  final referralExpired = "referral_expired";
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
  final bool? referralExpired;
  final int? reward;
  final int? rewardDuration;
  final int? rewardCreatedAt;
  final int? rewardExpireAt;

  String get noneUid {
    return id ?? DateTime
        .timestamp()
        .millisecondsSinceEpoch
        .toString();
  }

  bool get isCurrentUid => id == "1706388765933";

  bool get isEligible {
    return ReferralService.i.isEligibleWith(
      createdAt: rewardCreatedAt,
      days: rewardDuration,
    );
  }

  bool get isRedeemed => redeemed ?? false;

  bool get isReferralExpired => referralExpired ?? false;

  const UserModel({
    this.id,
    this.redeemed,
    this.redeemedCode,
    this.referralCode,
    this.referralExpired,
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
    final referralExpired = source[UserKeys.i.referralExpired];
    final reward = source[UserKeys.i.reward];
    final rewardDuration = source[UserKeys.i.rewardDuration];
    final rewardCreatedAt = source[UserKeys.i.rewardCreatedAt];
    final rewardExpireAt = source[UserKeys.i.rewardExpireAt];
    return UserModel(
      id: id is String ? id : null,
      redeemed: redeemed is bool ? redeemed : null,
      redeemedCode: redeemedCode is String ? redeemedCode : null,
      referralCode: referralCode is String ? referralCode : null,
      referralExpired: referralExpired is bool ? referralExpired : null,
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
    bool? referralExpired,
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
      referralExpired: referralExpired ?? this.referralExpired,
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
      UserKeys.i.referralExpired: referralExpired,
      UserKeys.i.reward: reward,
      UserKeys.i.rewardDuration: rewardDuration,
      UserKeys.i.rewardCreatedAt: rewardCreatedAt,
      UserKeys.i.rewardExpireAt: rewardExpireAt,
    };
  }
}
