(module
 (type $0 (func (param f32 f32 f32 f32 f32 f32 f32 f32 f32 f32 f32) (result f32)))
 (type $1 (func (param f32 f32 f32 f32 f32 f32 f32 f32 f32 f32) (result f32)))
 (type $2 (func (param f32 f32 f32 f32 f32 f32) (result i32)))
 (type $3 (func (param f32 f32 f32)))
 (type $4 (func (param f32) (result f32)))
 (type $5 (func))
 (global $input/rngState (mut i32) (i32.const 0))
 (global $input/hemDirX (mut f32) (f32.const 0))
 (global $input/hemDirY (mut f32) (f32.const 0))
 (global $input/hemDirZ (mut f32) (f32.const 0))
 (global $input/hitNx (mut f32) (f32.const 0))
 (global $input/hitNy (mut f32) (f32.const 0))
 (global $input/hitNz (mut f32) (f32.const 0))
 (global $input/sceneT (mut f32) (f32.const 0))
 (global $input/sceneNx (mut f32) (f32.const 0))
 (global $input/sceneNy (mut f32) (f32.const 0))
 (global $input/sceneNz (mut f32) (f32.const 0))
 (global $input/sceneMatR (mut f32) (f32.const 0))
 (global $input/sceneMatG (mut f32) (f32.const 0))
 (global $input/sceneMatB (mut f32) (f32.const 0))
 (global $input/sceneEmitR (mut f32) (f32.const 0))
 (global $input/sceneEmitG (mut f32) (f32.const 0))
 (global $input/sceneEmitB (mut f32) (f32.const 0))
 (global $input/ptResultR (mut f32) (f32.const 0))
 (global $input/ptResultG (mut f32) (f32.const 0))
 (global $input/ptResultB (mut f32) (f32.const 0))
 (memory $0 16 16)
 (export "main" (func $input/main))
 (export "memory" (memory $0))
 (func $input/intersectAABB (param $0 f32) (param $1 f32) (param $2 f32) (param $3 f32) (param $4 f32) (param $5 f32) (param $6 f32) (param $7 f32) (param $8 f32) (param $9 f32) (param $10 f32) (result f32)
  (local $11 f32)
  (local $12 f32)
  (local $13 f32)
  (local $14 f32)
  (local $15 f32)
  f32.const -100000002004087734272
  local.set $11
  f32.const 100000002004087734272
  local.set $12
  local.get $3
  f32.abs
  f32.const 9.99999993922529e-09
  f32.gt
  if
   f32.const -1
   local.set $12
   local.get $6
   local.get $0
   f32.sub
   local.get $3
   f32.div
   local.tee $6
   local.get $8
   local.get $0
   f32.sub
   local.get $3
   f32.div
   local.tee $0
   f32.gt
   if
    local.get $6
    local.get $0
    local.set $6
    f32.const 1
    local.set $12
    local.set $0
   end
   local.get $6
   f32.const -100000002004087734272
   f32.gt
   if (result f32)
    local.get $12
    local.set $13
    local.get $6
   else
    f32.const -100000002004087734272
   end
   local.set $11
   local.get $0
   f32.const 100000002004087734272
   local.get $0
   f32.const 100000002004087734272
   f32.lt
   select
   local.set $12
  else
   local.get $0
   local.get $6
   f32.lt
   local.get $0
   local.get $8
   f32.gt
   i32.or
   if
    f32.const -1
    return
   end
  end
  local.get $4
  f32.abs
  f32.const 9.99999993922529e-09
  f32.gt
  if
   f32.const -1
   local.set $6
   local.get $9
   local.get $1
   f32.sub
   local.get $4
   f32.div
   local.tee $0
   f32.const -1
   local.get $1
   f32.sub
   local.get $4
   f32.div
   local.tee $3
   f32.lt
   if
    local.get $3
    local.get $0
    local.set $3
    f32.const 1
    local.set $6
    local.set $0
   end
   local.get $3
   local.get $11
   f32.gt
   if
    f32.const 0
    local.set $13
    local.get $6
    local.set $14
    local.get $3
    local.set $11
   end
   local.get $0
   local.get $12
   local.get $0
   local.get $12
   f32.lt
   select
   local.set $12
  else
   local.get $1
   f32.const -1
   f32.lt
   local.get $1
   local.get $9
   f32.gt
   i32.or
   if
    f32.const -1
    return
   end
  end
  local.get $5
  f32.abs
  f32.const 9.99999993922529e-09
  f32.gt
  if
   f32.const -1
   local.set $3
   local.get $10
   local.get $2
   f32.sub
   local.get $5
   f32.div
   local.tee $0
   local.get $7
   local.get $2
   f32.sub
   local.get $5
   f32.div
   local.tee $1
   f32.lt
   if
    local.get $1
    local.get $0
    local.set $1
    f32.const 1
    local.set $3
    local.set $0
   end
   local.get $1
   local.get $11
   f32.gt
   if
    f32.const 0
    local.set $13
    f32.const 0
    local.set $14
    local.get $3
    local.set $15
    local.get $1
    local.set $11
   end
   local.get $0
   local.get $12
   local.get $0
   local.get $12
   f32.lt
   select
   local.set $12
  else
   local.get $2
   local.get $7
   f32.lt
   local.get $2
   local.get $10
   f32.gt
   i32.or
   if
    f32.const -1
    return
   end
  end
  local.get $12
  f32.const 0
  f32.lt
  local.get $11
  local.get $12
  f32.gt
  i32.or
  if
   f32.const -1
   return
  end
  local.get $11
  f32.const 1.0000000474974513e-03
  f32.lt
  if
   local.get $13
   f32.neg
   global.set $input/hitNx
   local.get $14
   f32.neg
   global.set $input/hitNy
   local.get $15
   f32.neg
   global.set $input/hitNz
   local.get $12
   return
  end
  local.get $13
  global.set $input/hitNx
  local.get $14
  global.set $input/hitNy
  local.get $15
  global.set $input/hitNz
  local.get $11
 )
 (func $input/intersectSphere (param $0 f32) (param $1 f32) (param $2 f32) (param $3 f32) (param $4 f32) (param $5 f32) (param $6 f32) (param $7 f32) (param $8 f32) (param $9 f32) (result f32)
  (local $10 f32)
  (local $11 f32)
  (local $12 f32)
  (local $13 f32)
  local.get $0
  local.get $6
  f32.sub
  local.tee $12
  local.get $3
  f32.mul
  local.get $1
  local.get $7
  f32.sub
  local.tee $10
  local.get $4
  f32.mul
  f32.add
  local.get $2
  local.get $8
  f32.sub
  local.tee $13
  local.get $5
  f32.mul
  f32.add
  local.tee $11
  local.get $11
  f32.mul
  local.get $12
  local.get $12
  f32.mul
  local.get $10
  local.get $10
  f32.mul
  f32.add
  local.get $13
  local.get $13
  f32.mul
  f32.add
  local.get $9
  local.get $9
  f32.mul
  f32.sub
  f32.sub
  local.tee $10
  f32.const 0
  f32.lt
  if
   f32.const -1
   return
  end
  local.get $11
  f32.neg
  local.get $10
  f32.sqrt
  local.tee $12
  f32.sub
  local.tee $10
  f32.const 1.0000000474974513e-03
  f32.lt
  if
   local.get $12
   local.get $11
   f32.sub
   local.set $10
  end
  local.get $10
  f32.const 1.0000000474974513e-03
  f32.lt
  if
   f32.const -1
   return
  end
  local.get $0
  local.get $3
  local.get $10
  f32.mul
  f32.add
  local.get $6
  f32.sub
  local.get $9
  f32.div
  global.set $input/hitNx
  local.get $1
  local.get $4
  local.get $10
  f32.mul
  f32.add
  local.get $7
  f32.sub
  local.get $9
  f32.div
  global.set $input/hitNy
  local.get $2
  local.get $5
  local.get $10
  f32.mul
  f32.add
  local.get $8
  f32.sub
  local.get $9
  f32.div
  global.set $input/hitNz
  local.get $10
 )
 (func $input/traceScene (param $0 f32) (param $1 f32) (param $2 f32) (param $3 f32) (param $4 f32) (param $5 f32) (result i32)
  (local $6 f32)
  (local $7 f32)
  (local $8 f32)
  (local $9 f32)
  (local $10 f32)
  (local $11 f32)
  (local $12 f32)
  (local $13 f32)
  (local $14 f32)
  (local $15 f32)
  (local $16 f32)
  (local $17 f32)
  (local $18 f32)
  local.get $5
  f32.abs
  f32.const 9.99999993922529e-09
  f32.gt
  if (result f32)
   f32.const 3
   local.get $2
   f32.sub
   local.get $5
   f32.div
   local.tee $6
   f32.const 100000002004087734272
   f32.lt
   local.get $6
   f32.const 1.0000000474974513e-03
   f32.gt
   i32.and
   if (result f32)
    local.get $0
    local.get $3
    local.get $6
    f32.mul
    f32.add
    local.tee $16
    f32.const 1
    f32.le
    local.get $16
    f32.const -1
    f32.ge
    i32.and
    local.get $1
    local.get $4
    local.get $6
    f32.mul
    f32.add
    local.tee $16
    f32.const -1
    f32.ge
    i32.and
    local.get $16
    f32.const 1
    f32.le
    i32.and
    if (result f32)
     f32.const -1
     local.set $7
     f32.const 0.7300000190734863
     local.set $8
     f32.const 0.7300000190734863
     local.set $9
     f32.const 0.7300000190734863
     local.set $10
     local.get $6
    else
     f32.const 100000002004087734272
    end
   else
    f32.const 100000002004087734272
   end
  else
   f32.const 100000002004087734272
  end
  local.set $6
  local.get $5
  f32.abs
  f32.const 9.99999993922529e-09
  f32.gt
  if
   f32.const -1
   local.get $2
   f32.sub
   local.get $5
   f32.div
   local.tee $16
   local.get $6
   f32.lt
   local.get $16
   f32.const 1.0000000474974513e-03
   f32.gt
   i32.and
   if
    local.get $0
    local.get $3
    local.get $16
    f32.mul
    f32.add
    local.tee $17
    f32.const 1
    f32.le
    local.get $17
    f32.const -1
    f32.ge
    i32.and
    local.get $1
    local.get $4
    local.get $16
    f32.mul
    f32.add
    local.tee $17
    f32.const -1
    f32.ge
    i32.and
    local.get $17
    f32.const 1
    f32.le
    i32.and
    if
     f32.const 1
     local.set $7
     f32.const 0.7300000190734863
     local.set $8
     f32.const 0.7300000190734863
     local.set $9
     f32.const 0.7300000190734863
     local.set $10
     local.get $16
     local.set $6
    end
   end
  end
  local.get $4
  f32.abs
  f32.const 9.99999993922529e-09
  f32.gt
  if
   f32.const -1
   local.get $1
   f32.sub
   local.get $4
   f32.div
   local.tee $16
   local.get $6
   f32.lt
   local.get $16
   f32.const 1.0000000474974513e-03
   f32.gt
   i32.and
   if
    local.get $0
    local.get $3
    local.get $16
    f32.mul
    f32.add
    local.tee $17
    f32.const 1
    f32.le
    local.get $17
    f32.const -1
    f32.ge
    i32.and
    local.get $2
    local.get $5
    local.get $16
    f32.mul
    f32.add
    local.tee $17
    f32.const -1
    f32.ge
    i32.and
    local.get $17
    f32.const 3
    f32.le
    i32.and
    if
     f32.const 1
     local.set $11
     f32.const 0
     local.set $7
     f32.const 0.7300000190734863
     local.set $8
     f32.const 0.7300000190734863
     local.set $9
     f32.const 0.7300000190734863
     local.set $10
     local.get $16
     local.set $6
    end
   end
  end
  local.get $4
  f32.abs
  f32.const 9.99999993922529e-09
  f32.gt
  if
   f32.const 1
   local.get $1
   f32.sub
   local.get $4
   f32.div
   local.tee $16
   local.get $6
   f32.lt
   local.get $16
   f32.const 1.0000000474974513e-03
   f32.gt
   i32.and
   if
    local.get $0
    local.get $3
    local.get $16
    f32.mul
    f32.add
    local.tee $17
    f32.const 1
    f32.le
    local.get $17
    f32.const -1
    f32.ge
    i32.and
    local.get $2
    local.get $5
    local.get $16
    f32.mul
    f32.add
    local.tee $17
    f32.const -1
    f32.ge
    i32.and
    local.get $17
    f32.const 3
    f32.le
    i32.and
    if
     f32.const -1
     local.set $11
     f32.const 0
     local.set $7
     f32.const 0.7300000190734863
     local.set $8
     f32.const 0.7300000190734863
     local.set $9
     f32.const 0.7300000190734863
     local.set $10
     local.get $16
     local.set $6
    end
   end
  end
  local.get $3
  f32.abs
  f32.const 9.99999993922529e-09
  f32.gt
  if
   f32.const -1
   local.get $0
   f32.sub
   local.get $3
   f32.div
   local.tee $16
   local.get $6
   f32.lt
   local.get $16
   f32.const 1.0000000474974513e-03
   f32.gt
   i32.and
   if
    local.get $1
    local.get $4
    local.get $16
    f32.mul
    f32.add
    local.tee $17
    f32.const 1
    f32.le
    local.get $17
    f32.const -1
    f32.ge
    i32.and
    local.get $2
    local.get $5
    local.get $16
    f32.mul
    f32.add
    local.tee $17
    f32.const -1
    f32.ge
    i32.and
    local.get $17
    f32.const 3
    f32.le
    i32.and
    if
     f32.const 1
     local.set $12
     f32.const 0
     local.set $11
     f32.const 0
     local.set $7
     f32.const 0.6499999761581421
     local.set $8
     f32.const 0.05000000074505806
     local.set $9
     f32.const 0.05000000074505806
     local.set $10
     local.get $16
     local.set $6
    end
   end
  end
  local.get $3
  f32.abs
  f32.const 9.99999993922529e-09
  f32.gt
  if
   f32.const 1
   local.get $0
   f32.sub
   local.get $3
   f32.div
   local.tee $16
   local.get $6
   f32.lt
   local.get $16
   f32.const 1.0000000474974513e-03
   f32.gt
   i32.and
   if
    local.get $1
    local.get $4
    local.get $16
    f32.mul
    f32.add
    local.tee $17
    f32.const 1
    f32.le
    local.get $17
    f32.const -1
    f32.ge
    i32.and
    local.get $2
    local.get $5
    local.get $16
    f32.mul
    f32.add
    local.tee $17
    f32.const -1
    f32.ge
    i32.and
    local.get $17
    f32.const 3
    f32.le
    i32.and
    if
     f32.const -1
     local.set $12
     f32.const 0
     local.set $11
     f32.const 0
     local.set $7
     f32.const 0.11999999731779099
     local.set $8
     f32.const 0.44999998807907104
     local.set $9
     f32.const 0.15000000596046448
     local.set $10
     local.get $16
     local.set $6
    end
   end
  end
  local.get $4
  f32.abs
  f32.const 9.99999993922529e-09
  f32.gt
  if
   f32.const 0.9900000095367432
   local.get $1
   f32.sub
   local.get $4
   f32.div
   local.tee $16
   local.get $6
   f32.lt
   local.get $16
   f32.const 1.0000000474974513e-03
   f32.gt
   i32.and
   if
    local.get $0
    local.get $3
    local.get $16
    f32.mul
    f32.add
    local.tee $17
    f32.const 0.3499999940395355
    f32.le
    local.get $17
    f32.const -0.3499999940395355
    f32.ge
    i32.and
    local.get $2
    local.get $5
    local.get $16
    f32.mul
    f32.add
    local.tee $17
    f32.const 0.699999988079071
    f32.ge
    i32.and
    local.get $17
    f32.const 1.399999976158142
    f32.le
    i32.and
    if
     f32.const 0
     local.set $12
     f32.const -1
     local.set $11
     f32.const 0
     local.set $7
     f32.const 0.7799999713897705
     local.set $8
     f32.const 0.7799999713897705
     local.set $9
     f32.const 0.7799999713897705
     local.set $10
     f32.const 18
     local.set $13
     f32.const 16
     local.set $14
     f32.const 10
     local.set $15
     local.get $16
     local.set $6
    end
   end
  end
  local.get $6
  local.get $0
  local.get $1
  local.get $2
  local.get $3
  local.get $4
  local.get $5
  f32.const 0.12999999523162842
  f32.const 0.6499999761581421
  f32.const 0.7300000190734863
  f32.const 0.20000000298023224
  f32.const 1.25
  call $input/intersectAABB
  local.tee $18
  f32.gt
  local.get $18
  f32.const 1.0000000474974513e-03
  f32.gt
  i32.and
  if
   global.get $input/hitNx
   local.set $12
   global.get $input/hitNy
   local.set $11
   global.get $input/hitNz
   local.set $7
   f32.const 0.7300000190734863
   local.set $8
   f32.const 0.7300000190734863
   local.set $9
   f32.const 0.7300000190734863
   local.set $10
   f32.const 0
   local.set $13
   f32.const 0
   local.set $14
   f32.const 0
   local.set $15
   local.get $18
   local.set $6
  end
  local.get $0
  local.get $1
  local.get $2
  local.get $3
  local.get $4
  local.get $5
  f32.const -0.7300000190734863
  f32.const 1.100000023841858
  f32.const -0.12999999523162842
  f32.const -0.4000000059604645
  f32.const 1.7000000476837158
  call $input/intersectAABB
  local.tee $16
  local.get $6
  f32.lt
  local.get $16
  f32.const 1.0000000474974513e-03
  f32.gt
  i32.and
  if
   global.get $input/hitNx
   local.set $12
   global.get $input/hitNy
   local.set $11
   global.get $input/hitNz
   local.set $7
   f32.const 0.7300000190734863
   local.set $8
   f32.const 0.7300000190734863
   local.set $9
   f32.const 0.7300000190734863
   local.set $10
   f32.const 0
   local.set $13
   f32.const 0
   local.set $14
   f32.const 0
   local.set $15
   local.get $16
   local.set $6
  end
  local.get $0
  local.get $1
  local.get $2
  local.get $3
  local.get $4
  local.get $5
  f32.const -0.4300000071525574
  f32.const -0.6499999761581421
  f32.const 1.399999976158142
  f32.const 0.3499999940395355
  call $input/intersectSphere
  local.tee $16
  local.get $6
  f32.lt
  local.get $16
  f32.const 1.0000000474974513e-03
  f32.gt
  i32.and
  if
   global.get $input/hitNx
   local.set $12
   global.get $input/hitNy
   local.set $11
   global.get $input/hitNz
   local.set $7
   f32.const 0.8999999761581421
   local.set $8
   f32.const 0.8999999761581421
   local.set $9
   f32.const 0.949999988079071
   local.set $10
   f32.const 0
   local.set $13
   f32.const 0
   local.set $14
   f32.const 0
   local.set $15
   local.get $16
   local.set $6
  end
  local.get $0
  local.get $1
  local.get $2
  local.get $3
  local.get $4
  local.get $5
  f32.const 0.4300000071525574
  f32.const 0.44999998807907104
  f32.const 0.949999988079071
  f32.const 0.25
  call $input/intersectSphere
  local.tee $0
  local.get $6
  f32.lt
  local.get $0
  f32.const 1.0000000474974513e-03
  f32.gt
  i32.and
  if
   global.get $input/hitNx
   local.set $12
   global.get $input/hitNy
   local.set $11
   global.get $input/hitNz
   local.set $7
   f32.const 0.949999988079071
   local.set $8
   f32.const 0.75
   local.set $9
   f32.const 0.4000000059604645
   local.set $10
   f32.const 0
   local.set $13
   f32.const 0
   local.set $14
   f32.const 0
   local.set $15
   local.get $0
   local.set $6
  end
  local.get $6
  f32.const 100000002004087734272
  f32.ge
  if
   i32.const 0
   return
  end
  local.get $6
  global.set $input/sceneT
  local.get $12
  global.set $input/sceneNx
  local.get $11
  global.set $input/sceneNy
  local.get $7
  global.set $input/sceneNz
  local.get $8
  global.set $input/sceneMatR
  local.get $9
  global.set $input/sceneMatG
  local.get $10
  global.set $input/sceneMatB
  local.get $13
  global.set $input/sceneEmitR
  local.get $14
  global.set $input/sceneEmitG
  local.get $15
  global.set $input/sceneEmitB
  i32.const 1
 )
 (func $input/sampleHemisphere (param $0 f32) (param $1 f32) (param $2 f32)
  (local $3 f32)
  (local $4 f32)
  (local $5 f32)
  (local $6 i32)
  (local $7 f32)
  (local $8 f32)
  (local $9 f32)
  (local $10 f32)
  (local $11 f32)
  (local $12 f32)
  global.get $input/rngState
  i32.const 747796405
  i32.mul
  i32.const 1403630843
  i32.sub
  global.set $input/rngState
  global.get $input/rngState
  global.get $input/rngState
  global.get $input/rngState
  i32.const 28
  i32.shr_u
  i32.const 4
  i32.add
  i32.shr_u
  i32.xor
  i32.const 277803737
  i32.mul
  local.tee $6
  local.get $6
  i32.const 22
  i32.shr_u
  i32.xor
  global.set $input/rngState
  global.get $input/rngState
  f32.convert_i32_u
  f32.const 2.3283064365386963e-10
  f32.mul
  global.get $input/rngState
  i32.const 747796405
  i32.mul
  i32.const 1403630843
  i32.sub
  global.set $input/rngState
  global.get $input/rngState
  global.get $input/rngState
  global.get $input/rngState
  i32.const 28
  i32.shr_u
  i32.const 4
  i32.add
  i32.shr_u
  i32.xor
  i32.const 277803737
  i32.mul
  local.tee $6
  local.get $6
  i32.const 22
  i32.shr_u
  i32.xor
  global.set $input/rngState
  global.get $input/rngState
  f32.convert_i32_u
  f32.const 2.3283064365386963e-10
  f32.mul
  local.tee $10
  f32.sqrt
  local.set $4
  f32.const 6.2831854820251465
  f32.mul
  local.set $11
  local.get $1
  local.get $1
  f32.abs
  f32.const 0.8999999761581421
  f32.gt
  if (result f32)
   local.get $2
   f32.const 1
   local.get $2
   local.get $2
   f32.mul
   local.get $1
   local.get $1
   f32.mul
   f32.add
   f32.sqrt
   f32.div
   local.tee $3
   f32.mul
   local.set $7
   local.get $1
   f32.neg
   local.get $3
   f32.mul
  else
   local.get $2
   f32.neg
   f32.const 1
   local.get $2
   local.get $2
   f32.mul
   local.get $0
   local.get $0
   f32.mul
   f32.add
   f32.sqrt
   f32.div
   local.tee $3
   f32.mul
   local.set $5
   local.get $0
   local.get $3
   f32.mul
  end
  local.tee $9
  f32.mul
  local.get $2
  local.get $7
  f32.mul
  f32.sub
  local.set $8
  local.get $11
  f32.const 1.5707963705062866
  f32.add
  local.tee $3
  local.get $3
  f32.const 6.2831854820251465
  f32.div
  f32.const 0.5
  f32.add
  f32.floor
  f32.const 6.2831854820251465
  f32.mul
  f32.sub
  local.tee $3
  f32.const 1.5707963705062866
  f32.gt
  if
   f32.const 3.1415927410125732
   local.get $3
   f32.sub
   local.set $3
  end
  local.get $3
  f32.const -1.5707963705062866
  f32.lt
  if
   f32.const -3.1415927410125732
   local.get $3
   f32.sub
   local.set $3
  end
  local.get $5
  local.get $4
  f32.mul
  local.get $3
  f32.const 1
  local.get $3
  local.get $3
  f32.mul
  local.tee $3
  f32.const 6
  f32.div
  f32.const 1
  local.get $3
  f32.const 20
  f32.div
  f32.const 1
  local.get $3
  f32.const 42
  f32.div
  f32.sub
  f32.mul
  f32.sub
  f32.mul
  f32.sub
  f32.mul
  local.tee $12
  f32.mul
  local.get $11
  local.get $11
  f32.const 6.2831854820251465
  f32.div
  f32.const 0.5
  f32.add
  f32.floor
  f32.const 6.2831854820251465
  f32.mul
  f32.sub
  local.tee $3
  f32.const 1.5707963705062866
  f32.gt
  if
   f32.const 3.1415927410125732
   local.get $3
   f32.sub
   local.set $3
  end
  local.get $3
  f32.const -1.5707963705062866
  f32.lt
  if
   f32.const -3.1415927410125732
   local.get $3
   f32.sub
   local.set $3
  end
  local.get $8
  local.get $4
  f32.mul
  local.get $3
  f32.const 1
  local.get $3
  local.get $3
  f32.mul
  local.tee $3
  f32.const 6
  f32.div
  f32.const 1
  local.get $3
  f32.const 20
  f32.div
  f32.const 1
  local.get $3
  f32.const 42
  f32.div
  f32.sub
  f32.mul
  f32.sub
  f32.mul
  f32.sub
  f32.mul
  local.tee $3
  f32.mul
  f32.add
  local.get $0
  f32.const 1
  local.get $10
  f32.sub
  f32.sqrt
  local.tee $8
  f32.mul
  f32.add
  global.set $input/hemDirX
  local.get $7
  local.get $4
  f32.mul
  local.get $12
  f32.mul
  local.get $2
  local.get $5
  f32.mul
  local.get $0
  local.get $9
  f32.mul
  f32.sub
  local.get $4
  f32.mul
  local.get $3
  f32.mul
  f32.add
  local.get $1
  local.get $8
  f32.mul
  f32.add
  global.set $input/hemDirY
  local.get $9
  local.get $4
  f32.mul
  local.get $12
  f32.mul
  local.get $0
  local.get $7
  f32.mul
  local.get $1
  local.get $5
  f32.mul
  f32.sub
  local.get $4
  f32.mul
  local.get $3
  f32.mul
  f32.add
  local.get $2
  local.get $8
  f32.mul
  f32.add
  global.set $input/hemDirZ
 )
 (func $input/powF (param $0 f32) (result f32)
  (local $1 i32)
  (local $2 i32)
  (local $3 f32)
  (local $4 f32)
  local.get $0
  f32.const 0
  f32.le
  if
   f32.const 0
   return
  end
  block $__inlined_func$input/expF$6 (result f32)
   f32.const 0
   local.get $0
   f32.const 0
   f32.le
   if (result f32)
    f32.const -100
   else
    loop $while-continue|0
     local.get $0
     f32.const 2
     f32.ge
     if
      local.get $0
      f32.const 0.5
      f32.mul
      local.set $0
      local.get $1
      i32.const 1
      i32.add
      local.set $1
      br $while-continue|0
     end
    end
    loop $while-continue|1
     local.get $0
     f32.const 1
     f32.lt
     if
      local.get $0
      local.get $0
      f32.add
      local.set $0
      local.get $1
      i32.const 1
      i32.sub
      local.set $1
      br $while-continue|1
     end
    end
    local.get $0
    f32.const -1
    f32.add
    local.get $0
    f32.const 1
    f32.add
    f32.div
    local.tee $0
    local.get $0
    f32.mul
    local.set $3
    local.get $1
    f32.convert_i32_s
    f32.const 0.6931471824645996
    f32.mul
    local.get $0
    local.get $0
    f32.add
    local.get $3
    local.get $3
    f32.const 0.20000000298023224
    f32.mul
    f32.const 0.3333333134651184
    f32.add
    f32.mul
    f32.const 1
    f32.add
    f32.mul
    f32.add
   end
   f32.const 0.4544999897480011
   f32.mul
   local.tee $0
   f32.const -20
   f32.lt
   br_if $__inlined_func$input/expF$6
   drop
   f32.const 485165184
   local.get $0
   f32.const 20
   f32.gt
   br_if $__inlined_func$input/expF$6
   drop
   local.get $0
   local.get $0
   f32.const 1.4426950216293335
   f32.mul
   f32.floor
   local.tee $3
   f32.const 0.6931471824645996
   f32.mul
   f32.sub
   local.tee $0
   local.get $0
   local.get $0
   local.get $0
   f32.const 0.0416666716337204
   f32.mul
   f32.const 0.16666670143604279
   f32.add
   f32.mul
   f32.const 0.5
   f32.add
   f32.mul
   f32.const 1
   f32.add
   f32.mul
   f32.const 1
   f32.add
   local.set $4
   f32.const 1
   local.set $0
   local.get $3
   i32.trunc_sat_f32_s
   local.tee $1
   i32.const 0
   i32.gt_s
   if
    loop $for-loop|0
     local.get $1
     local.get $2
     i32.gt_s
     if
      local.get $0
      local.get $0
      f32.add
      local.set $0
      local.get $2
      i32.const 1
      i32.add
      local.set $2
      br $for-loop|0
     end
    end
   else
    i32.const 0
    local.get $1
    i32.sub
    local.set $1
    loop $for-loop|1
     local.get $1
     local.get $2
     i32.gt_s
     if
      local.get $0
      f32.const 0.5
      f32.mul
      local.set $0
      local.get $2
      i32.const 1
      i32.add
      local.set $2
      br $for-loop|1
     end
    end
   end
   local.get $0
   local.get $4
   f32.mul
  end
 )
 (func $input/main
  (local $0 f32)
  (local $1 i32)
  (local $2 f32)
  (local $3 f32)
  (local $4 f32)
  (local $5 f32)
  (local $6 f32)
  (local $7 f32)
  (local $8 i32)
  (local $9 f32)
  (local $10 f32)
  (local $11 f32)
  (local $12 i32)
  (local $13 f32)
  (local $14 f32)
  (local $15 f32)
  (local $16 f32)
  (local $17 f32)
  (local $18 i32)
  (local $19 i32)
  (local $20 i32)
  (local $21 i32)
  (local $22 f32)
  (local $23 f32)
  (local $24 f32)
  i32.const 0
  f32.load
  i32.trunc_sat_f32_s
  local.set $18
  loop $for-loop|0
   local.get $1
   i32.const 65536
   i32.lt_s
   if
    local.get $1
    i32.const 256
    i32.rem_s
    local.tee $19
    i32.const 1973
    i32.mul
    local.get $1
    i32.const 256
    i32.div_s
    local.tee $20
    i32.const 9277
    i32.mul
    i32.add
    local.get $18
    i32.const 26699
    i32.mul
    i32.add
    i32.const 1
    i32.or
    global.set $input/rngState
    global.get $input/rngState
    i32.const 747796405
    i32.mul
    i32.const 1403630843
    i32.sub
    global.set $input/rngState
    global.get $input/rngState
    global.get $input/rngState
    global.get $input/rngState
    i32.const 28
    i32.shr_u
    i32.const 4
    i32.add
    i32.shr_u
    i32.xor
    i32.const 277803737
    i32.mul
    local.tee $8
    i32.const 22
    i32.shr_u
    local.get $8
    i32.xor
    global.set $input/rngState
    global.get $input/rngState
    i32.const 747796405
    i32.mul
    i32.const 1403630843
    i32.sub
    global.set $input/rngState
    global.get $input/rngState
    global.get $input/rngState
    global.get $input/rngState
    i32.const 28
    i32.shr_u
    i32.const 4
    i32.add
    i32.shr_u
    i32.xor
    i32.const 277803737
    i32.mul
    local.tee $8
    i32.const 22
    i32.shr_u
    local.get $8
    i32.xor
    global.set $input/rngState
    f32.const 0
    local.set $9
    f32.const 0
    local.set $10
    f32.const 0
    local.set $11
    i32.const 0
    local.set $12
    loop $for-loop|1
     local.get $12
     i32.const 100
     i32.lt_s
     if
      f32.const 0
      local.set $13
      f32.const 0
      local.set $14
      f32.const 0
      local.set $15
      f32.const 1
      local.set $3
      f32.const 1
      local.set $0
      f32.const 0
      local.set $4
      f32.const 0
      local.set $5
      f32.const -0.8999999761581421
      local.set $6
      global.get $input/rngState
      i32.const 747796405
      i32.mul
      i32.const 1403630843
      i32.sub
      global.set $input/rngState
      global.get $input/rngState
      global.get $input/rngState
      global.get $input/rngState
      i32.const 28
      i32.shr_u
      i32.const 4
      i32.add
      i32.shr_u
      i32.xor
      i32.const 277803737
      i32.mul
      local.tee $8
      i32.const 22
      i32.shr_u
      local.get $8
      i32.xor
      global.set $input/rngState
      local.get $19
      f32.convert_i32_s
      global.get $input/rngState
      f32.convert_i32_u
      f32.const 2.3283064365386963e-10
      f32.mul
      f32.add
      f32.const 2
      f32.mul
      f32.const 0.00390625
      f32.mul
      f32.const -1
      f32.add
      f32.const 1.2000000476837158
      f32.mul
      local.set $2
      global.get $input/rngState
      i32.const 747796405
      i32.mul
      i32.const 1403630843
      i32.sub
      global.set $input/rngState
      global.get $input/rngState
      global.get $input/rngState
      global.get $input/rngState
      i32.const 28
      i32.shr_u
      i32.const 4
      i32.add
      i32.shr_u
      i32.xor
      i32.const 277803737
      i32.mul
      local.tee $8
      i32.const 22
      i32.shr_u
      local.get $8
      i32.xor
      global.set $input/rngState
      f32.const 1
      local.set $7
      local.get $2
      local.get $2
      local.get $2
      f32.mul
      local.get $20
      f32.convert_i32_s
      global.get $input/rngState
      f32.convert_i32_u
      f32.const 2.3283064365386963e-10
      f32.mul
      f32.add
      f32.const 2
      f32.mul
      f32.const 0.00390625
      f32.mul
      f32.const -1
      f32.add
      f32.const -1.2000000476837158
      f32.mul
      local.tee $2
      local.get $2
      f32.mul
      f32.add
      f32.const 1
      f32.add
      f32.sqrt
      local.tee $22
      f32.div
      local.set $16
      local.get $2
      local.get $22
      f32.div
      local.set $17
      f32.const 1
      local.get $22
      f32.div
      local.set $2
      i32.const 0
      local.set $8
      loop $for-loop|00
       local.get $8
       i32.const 5
       i32.lt_s
       if
        block $for-break0
         local.get $4
         local.get $5
         local.get $6
         local.get $16
         local.get $17
         local.get $2
         call $input/traceScene
         i32.eqz
         br_if $for-break0
         local.get $13
         local.get $7
         global.get $input/sceneEmitR
         f32.mul
         f32.add
         local.set $13
         local.get $14
         local.get $3
         global.get $input/sceneEmitG
         f32.mul
         f32.add
         local.set $14
         local.get $15
         local.get $0
         global.get $input/sceneEmitB
         f32.mul
         f32.add
         local.set $15
         global.get $input/sceneEmitR
         global.get $input/sceneEmitG
         f32.add
         global.get $input/sceneEmitB
         f32.add
         f32.const 0
         f32.gt
         br_if $for-break0
         local.get $7
         global.get $input/sceneMatR
         f32.mul
         local.set $7
         local.get $3
         global.get $input/sceneMatG
         f32.mul
         local.set $3
         local.get $0
         global.get $input/sceneMatB
         f32.mul
         local.set $0
         local.get $8
         i32.const 1
         i32.gt_s
         if
          global.get $input/rngState
          i32.const 747796405
          i32.mul
          i32.const 1403630843
          i32.sub
          global.set $input/rngState
          global.get $input/rngState
          global.get $input/rngState
          global.get $input/rngState
          i32.const 28
          i32.shr_u
          i32.const 4
          i32.add
          i32.shr_u
          i32.xor
          i32.const 277803737
          i32.mul
          local.tee $21
          i32.const 22
          i32.shr_u
          local.get $21
          i32.xor
          global.set $input/rngState
          local.get $0
          local.get $3
          f32.max
          local.get $7
          f32.max
          local.tee $22
          global.get $input/rngState
          f32.convert_i32_u
          f32.const 2.3283064365386963e-10
          f32.mul
          f32.lt
          br_if $for-break0
          local.get $7
          f32.const 1
          local.get $22
          f32.div
          local.tee $22
          f32.mul
          local.set $7
          local.get $3
          local.get $22
          f32.mul
          local.set $3
          local.get $0
          local.get $22
          f32.mul
          local.set $0
         end
         local.get $4
         local.get $16
         global.get $input/sceneT
         f32.mul
         f32.add
         local.get $5
         local.get $17
         global.get $input/sceneT
         f32.mul
         f32.add
         local.set $22
         local.get $6
         local.get $2
         global.get $input/sceneT
         f32.mul
         f32.add
         local.set $23
         global.get $input/sceneNx
         local.tee $24
         global.get $input/sceneNy
         local.tee $5
         global.get $input/sceneNz
         local.tee $6
         call $input/sampleHemisphere
         global.get $input/hemDirX
         local.set $16
         global.get $input/hemDirY
         local.set $17
         global.get $input/hemDirZ
         local.set $2
         local.get $24
         f32.const 1.0000000474974513e-03
         f32.mul
         f32.add
         local.set $4
         local.get $22
         local.get $5
         f32.const 1.0000000474974513e-03
         f32.mul
         f32.add
         local.set $5
         local.get $23
         local.get $6
         f32.const 1.0000000474974513e-03
         f32.mul
         f32.add
         local.set $6
         local.get $8
         i32.const 1
         i32.add
         local.set $8
         br $for-loop|00
        end
       end
      end
      local.get $13
      global.set $input/ptResultR
      local.get $14
      global.set $input/ptResultG
      local.get $15
      global.set $input/ptResultB
      local.get $9
      global.get $input/ptResultR
      f32.add
      local.set $9
      local.get $10
      global.get $input/ptResultG
      f32.add
      local.set $10
      local.get $11
      global.get $input/ptResultB
      f32.add
      local.set $11
      local.get $12
      i32.const 1
      i32.add
      local.set $12
      br $for-loop|1
     end
    end
    local.get $9
    f32.const 0.009999999776482582
    f32.mul
    local.tee $0
    local.get $0
    f32.const 1
    f32.add
    f32.div
    call $input/powF
    local.set $0
    local.get $10
    f32.const 0.009999999776482582
    f32.mul
    local.tee $2
    local.get $2
    f32.const 1
    f32.add
    f32.div
    call $input/powF
    local.set $2
    local.get $11
    f32.const 0.009999999776482582
    f32.mul
    local.tee $3
    local.get $3
    f32.const 1
    f32.add
    f32.div
    call $input/powF
    local.set $3
    local.get $1
    i32.const 12
    i32.mul
    local.tee $8
    i32.const 16
    i32.add
    local.get $0
    f32.const 0
    f32.max
    f32.const 1
    f32.min
    f32.const 255
    f32.mul
    i32.trunc_sat_f32_s
    i32.store
    local.get $8
    local.get $2
    f32.const 0
    f32.max
    f32.const 1
    f32.min
    f32.const 255
    f32.mul
    i32.trunc_sat_f32_s
    i32.store offset=20
    local.get $8
    local.get $3
    f32.const 0
    f32.max
    f32.const 1
    f32.min
    f32.const 255
    f32.mul
    i32.trunc_sat_f32_s
    i32.store offset=24
    local.get $1
    i32.const 1
    i32.add
    local.set $1
    br $for-loop|0
   end
  end
 )
)