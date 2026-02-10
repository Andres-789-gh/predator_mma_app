import 'package:equatable/equatable.dart';
import '../../../auth/domain/models/user_model.dart';

enum SalesStatus { initial, loadingUsers, ready, processing, success, failure }

class SalesState extends Equatable {
  final SalesStatus status;
  final List<UserModel> users;
  final String? errorMessage;

  const SalesState({
    this.status = SalesStatus.initial,
    this.users = const [],
    this.errorMessage,
  });

  SalesState copyWith({
    SalesStatus? status,
    List<UserModel>? users,
    String? errorMessage,
  }) {
    return SalesState(
      status: status ?? this.status,
      users: users ?? this.users,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, users, errorMessage];
}
