import Foundation

func detachedCancellable<T: Sendable>(
    priority: TaskPriority,
    _ operation: @escaping @Sendable () async -> T
) async -> T {
    let task = Task.detached(priority: priority, operation: operation)
    return await withTaskCancellationHandler {
        await task.value
    } onCancel: {
        task.cancel()
    }
}
