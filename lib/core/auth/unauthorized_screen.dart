import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class UnauthorizedScreen extends StatelessWidget {
  final String attemptedRole;
  final List<String> requiredRoles;

  const UnauthorizedScreen({
    required this.attemptedRole,
    required this.requiredRoles,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('અધિકૃત નથી'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 24),
              Text(
                'આ પૃષ્ઠનું પ્રવેશ નક્કી કરવામાં આવ્યું છે',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'તમારા ભૂમિકા "$attemptedRole" આ વિભાગે પ્રવેશાધિકાર નથી.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'જરૂરી ભૂમિકા: ${requiredRoles.join(", ")}',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('પાછળ જાઓ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
