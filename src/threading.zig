// --- std --- //
const Allocator = @import("std").mem.Allocator;
const Thread = @import("std").Thread;

/// A token that can be passed across routines
/// to request a cancellation of the execution.
///
/// The underlying routine(s) are responsible for
/// responding to changes on the token value.
pub const CancellationToken = struct {
    /// Whether the cancellation token is set
    is_set: bool
};

const BackgroundThread = struct {
    /// The allocator used for allocating the background thread
    _allocator: *const Allocator,

    /// A pointer to the allocated background thread
    _ptr: *const BackgroundThread,

    /// The underlying thread
    _thread: Thread,

    /// Whether the thread has been joined
    _joined: *bool,

    /// The cancellation token for the underlying thread
    cancellation_token: *CancellationToken,

    /// Sets the cancellation token on the thread and waits
    /// for it to complete execution
    pub fn cancel(self: *const BackgroundThread) void {
        self.cancellation_token.*.is_set = true;
        join(self);
    }

    /// Waits for the underlying thread to complete execution
    /// and deallocates the resources reserved during spawn
    pub fn join(self: *const BackgroundThread) void {
        if(self._joined.*) return;
        self._joined.* = true;
        self._thread.join();
    }

    /// Deallocates the resources occupied by the background thread
    ///
    /// Note that this will not stop the underlying thread. For that
    /// either call `join` or `cancel`.
    pub fn deallocate(self: *const BackgroundThread) void {
        self._allocator.destroy(self._joined);
        self._allocator.destroy(self.cancellation_token);
        self._allocator.destroy(self);
    }
};

/// Spawns a new background thread with the specified `routine` and `params`.
pub fn spawnBackgroundThread(T: type, allocator: *const Allocator, routine: fn (_: *const CancellationToken, params: T) void, params: T) (Allocator.Error || Thread.SpawnError)!*const BackgroundThread {
    const bt = try allocator.create(BackgroundThread);
    errdefer allocator.destroy(bt);
    bt._allocator = allocator;
    bt._ptr = bt;

    const ct = try allocator.create(CancellationToken);
    errdefer allocator.destroy(ct);
    bt.cancellation_token = ct;

    const joined = try allocator.create(bool);
    errdefer allocator.destroy(joined);
    bt._joined = joined;

    const thread = try Thread.spawn(. { }, routine, .{ bt.cancellation_token, params });
    bt._thread = thread;

    return bt;
}


pub fn sleep(ns: u64) void {
    Thread.sleep(ns);
}
