import 'dart:isolate';
import 'dart:ui';

class BackgroundService {
  /// creates a listener for a background task, so that the app can be notified
  /// when the background task sends a message
  static void createListenerForTask({
    required String task,
    Function(dynamic)? callback,
  }) {
    final port = ReceivePort(task);
    final success = IsolateNameServer.registerPortWithName(
      port.sendPort,
      task,
    );
    // if the port is already registered or some issue occurred, try again
    if (!success) {
      removeListenerForTask(task);
      createListenerForTask(
        task: task,
        callback: callback,
      );
      return;
    }
    port.listen(callback);
  }

  /// returns the producer for a background task so that it can be used to send
  /// messages to the background task listener
  static SendPort? getProducerForTask(String task) =>
      IsolateNameServer.lookupPortByName(
        task,
      );

  /// removes the listener for a background task
  static void removeListenerForTask(String task) =>
      IsolateNameServer.removePortNameMapping(
        task,
      );
}
