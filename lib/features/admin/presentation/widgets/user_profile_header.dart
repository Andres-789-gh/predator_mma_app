import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../../../core/widgets/smart_avatar.dart';

class UserProfileHeader extends StatelessWidget {
  final UserModel user;
  final VoidCallback onToggleLegacyStatus;

  const UserProfileHeader({
    super.key,
    required this.user,
    required this.onToggleLegacyStatus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      color: theme.scaffoldBackgroundColor,
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (user.profilePictureUrl != null &&
                  user.profilePictureUrl!.trim().isNotEmpty) {
                _showImageDialog(context, user.profilePictureUrl!);
              }
            },
            child: SmartAvatar(
              photoUrl: user.profilePictureUrl,
              name: user.firstName,
              radius: 35,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "CC: ${user.documentId}",
                  style: TextStyle(color: theme.textTheme.bodySmall?.color),
                ),
                const SizedBox(height: 5),
                // boton unico de estado
                InkWell(
                  onTap: onToggleLegacyStatus,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: user.isLegacyUser
                          ? Colors.amber.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: user.isLegacyUser ? Colors.amber : Colors.grey,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          user.isLegacyUser ? Icons.star : Icons.star_border,
                          size: 16,
                          color: user.isLegacyUser
                              ? Colors.orange
                              : Colors.grey,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          "Usuario Antiguo",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: user.isLegacyUser
                                ? Colors.orange[800]
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ver foto en grande
  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            placeholder: (context, url) => const Center(
              child: CircularProgressIndicator(color: Colors.red),
            ),
            errorWidget: (context, url, error) => Container(
              color: Colors.black,
              child: const Icon(Icons.error, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
