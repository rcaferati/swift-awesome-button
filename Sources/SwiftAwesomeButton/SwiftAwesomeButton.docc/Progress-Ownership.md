# Progress Ownership

Set `progress` to `true` when activation should hand a one-shot completion handle to `onPress`. Call the handle once after the operation finishes; duplicate and stale calls are ignored.

`showProgressBar` controls only the visual progress layer. Setting it to `false` preserves busy state, callback ordering, cancellation, and completion ownership.

Release and progress-completion callbacks are captured when their transitions begin. Replacing later callbacks does not retarget an already-started transition.
