import 'package:equatable/equatable.dart';
import '../../domain/models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

// Estado inicial
class AuthInitial extends AuthState {
  const AuthInitial(); 
}

// Cargando
class AuthLoading extends AuthState {
  const AuthLoading(); 
}

// Autenticado
class AuthAuthenticated extends AuthState {
  final UserModel user;
  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

// No Autenticado
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated(); 
}

// Error
class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}