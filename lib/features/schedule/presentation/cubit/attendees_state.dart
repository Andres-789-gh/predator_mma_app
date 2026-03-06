import 'package:equatable/equatable.dart';
import '../../../auth/domain/models/user_model.dart';

abstract class AttendeesState extends Equatable {
  const AttendeesState();

  @override
  List<Object?> get props => [];
}

class AttendeesInitial extends AttendeesState {}

class AttendeesLoading extends AttendeesState {}

class AttendeesLoaded extends AttendeesState {
  final List<UserModel> attendees;
  final List<UserModel> waitlist;

  const AttendeesLoaded({required this.attendees, required this.waitlist});

  @override
  List<Object?> get props => [attendees, waitlist];
}

class AttendeesError extends AttendeesState {
  final String message;

  const AttendeesError(this.message);

  @override
  List<Object?> get props => [message];
}
