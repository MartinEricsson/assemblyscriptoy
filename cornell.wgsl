// Gasm Compiler Generated WGSL
// Compiler Version: 0.3.2
// Build Date: 2026-02-27
// Generated: 2026-03-03T15:28:37.266Z
// Source Language: Unknown | Debug Info: low

@group(0) @binding(0) var<storage, read_write> memory: array<u32>;

fn wgsl_load_i32(idx: u32) -> i32 { return bitcast<i32>(memory[idx]); }
fn wgsl_store_i32(idx: u32, val: i32) { memory[idx] = bitcast<u32>(val); }
fn wgsl_load_f32(idx: u32) -> f32 { return bitcast<f32>(memory[idx]); }
fn wgsl_store_f32(idx: u32, val: f32) { memory[idx] = bitcast<u32>(val); }
fn wgsl_buffer_length() -> u32 { return arrayLength(&memory); }

var<private> global_0: i32 = 0i;
var<private> global_1: f32 = 0.0f;
var<private> global_2: f32 = 0.0f;
var<private> global_3: f32 = 0.0f;
var<private> global_4: f32 = 0.0f;
var<private> global_5: f32 = 0.0f;
var<private> global_6: f32 = 0.0f;
var<private> global_7: f32 = 0.0f;
var<private> global_8: f32 = 0.0f;
var<private> global_9: f32 = 0.0f;
var<private> global_10: f32 = 0.0f;
var<private> global_11: f32 = 0.0f;
var<private> global_12: f32 = 0.0f;
var<private> global_13: f32 = 0.0f;
var<private> global_14: f32 = 0.0f;
var<private> global_15: f32 = 0.0f;
var<private> global_16: f32 = 0.0f;
var<private> global_17: f32 = 0.0f;
var<private> global_18: f32 = 0.0f;
var<private> global_19: f32 = 0.0f;
var<private> _wgpu_global_idx: u32 = 0u;

// Function 0: "func_0"
fn func_0(p0: f32, p1: f32, p2: f32, p3: f32, p4: f32, p5: f32, p6: f32, p7: f32, p8: f32, p9: f32, p10: f32) -> f32 {
  var local_0 = p0;
  var local_1 = p1;
  var local_3 = p3;
  var local_6 = p6;
  var local_11: f32;
  var local_12: f32;
  var local_13: f32;
  var local_14: f32;
  var local_15: f32;
  var v26: f32;
  var v27: f32;
  var v32: f32;
  var v34: f32;
  var v35: f32;
  var v41: f32;
  var v42: f32;
  var v40: f32;
  var v67: f32;
  var v72: f32;
  var v74: f32;
  var v75: f32;
  var v82: f32;
  var v106: f32;
  var v111: f32;
  var v113: f32;
  var v114: f32;
  // [WAT] local.set
  local_11 = -100000002004087730000.0f;
  // [WAT] local.set
  local_12 = 100000002004087730000.0f;
  // [WAT] local.get
  let v18 = local_3;
  if (abs(v18) > 9.99999993922529e-9f) {
    // [WAT] local.set
    local_12 = -1.0f;
    // [WAT] local.get
    let v23 = local_6;
    // [WAT] local.get
    let v24 = local_0;
    // [WAT] local.get
    v26 = local_3;
    // [WAT] f32.div
    v27 = ((v23 - v24) / v26);
    // [WAT] local.set
    local_6 = v27;
    // [WAT] f32.div
    v32 = ((p8 - v24) / v26);
    // [WAT] local.set
    local_0 = v32;
    if (v27 > v32) {
      // [WAT] local.get
      v34 = local_6;
      // [WAT] local.get
      v35 = local_0;
      // [WAT] local.set
      local_6 = v35;
      // [WAT] local.set
      local_12 = 1.0f;
      // [WAT] local.set
      local_0 = v34;
    }
    {
      // [WAT] local.get
      let v37 = local_6;
      if (v37 > -100000002004087730000.0f) {
        // [WAT] local.get
        v41 = local_12;
        // [WAT] local.set
        local_13 = v41;
        // [WAT] local.get
        v42 = local_6;
        // [WAT] assign
        v40 = v42;
      } else {
        // [WAT] assign
        v40 = -100000002004087730000.0f;
      }
      // [WAT] local.set
      local_11 = v40;
      // [WAT] local.get
      let v44 = local_0;
      // [WAT] local.set
      local_12 = select(100000002004087730000.0f, v44, (select(0i, 1i, v44 < 100000002004087730000.0f) != 0));
    }
  } else {
    // [WAT] local.get
    let v50 = local_0;
    // [WAT] local.get
    let v51 = local_6;
    if ((select(0i, 1i, v50 < v51) | select(0i, 1i, v50 > p8)) != 0) {
      // [WAT] return
      return -1.0f;
    }
  }
  {
    if (abs(p4) > 9.99999993922529e-9f) {
      // [WAT] local.set
      local_6 = -1.0f;
      // [WAT] local.get
      let v64 = local_1;
      // [WAT] f32.div
      v67 = ((p9 - v64) / p4);
      // [WAT] local.set
      local_0 = v67;
      // [WAT] f32.div
      v72 = ((-1.0f - v64) / p4);
      // [WAT] local.set
      local_3 = v72;
      if (v67 < v72) {
        // [WAT] local.get
        v74 = local_3;
        // [WAT] local.get
        v75 = local_0;
        // [WAT] local.set
        local_3 = v75;
        // [WAT] local.set
        local_6 = 1.0f;
        // [WAT] local.set
        local_0 = v74;
      }
      {
        // [WAT] local.get
        let v77 = local_3;
        // [WAT] local.get
        let v78 = local_11;
        if (v77 > v78) {
          // [WAT] local.set
          local_13 = 0.0f;
          // [WAT] local.set
          local_14 = local_6;
          // [WAT] local.get
          v82 = local_3;
          // [WAT] local.set
          local_11 = v82;
        }
        // [WAT] local.get
        let v83 = local_0;
        // [WAT] local.get
        let v84 = local_12;
        // [WAT] local.set
        local_12 = select(v84, v83, (select(0i, 1i, v83 < v84) != 0));
      }
    } else {
      // [WAT] local.get
      let v89 = local_1;
      if ((select(0i, 1i, v89 < -1.0f) | select(0i, 1i, v89 > p9)) != 0) {
        // [WAT] return
        return -1.0f;
      }
    }
    {
      if (abs(p5) > 9.99999993922529e-9f) {
        // [WAT] local.set
        local_3 = -1.0f;
        // [WAT] f32.div
        v106 = ((p10 - p2) / p5);
        // [WAT] local.set
        local_0 = v106;
        // [WAT] f32.div
        v111 = ((p7 - p2) / p5);
        // [WAT] local.set
        local_1 = v111;
        if (v106 < v111) {
          // [WAT] local.get
          v113 = local_1;
          // [WAT] local.get
          v114 = local_0;
          // [WAT] local.set
          local_1 = v114;
          // [WAT] local.set
          local_3 = 1.0f;
          // [WAT] local.set
          local_0 = v113;
        }
        {
          // [WAT] local.get
          let v117 = local_11;
          if (local_1 > v117) {
            // [WAT] local.set
            local_13 = 0.0f;
            // [WAT] local.set
            local_14 = 0.0f;
            // [WAT] local.set
            local_15 = local_3;
            // [WAT] local.set
            local_11 = local_1;
          }
          // [WAT] local.get
          let v123 = local_0;
          // [WAT] local.get
          let v124 = local_12;
          // [WAT] local.set
          local_12 = select(v124, v123, (select(0i, 1i, v123 < v124) != 0));
        }
      } else {
        if ((select(0i, 1i, p2 < p7) | select(0i, 1i, p2 > p10)) != 0) {
          // [WAT] return
          return -1.0f;
        }
      }
      {
        // [WAT] local.get
        let v137 = local_12;
        if ((select(0i, 1i, v137 < 0.0f) | select(0i, 1i, local_11 > v137)) != 0) {
          // [WAT] return
          return -1.0f;
        } else {
          if (local_11 < 0.0010000000474974513f) {
            // [WAT] global.set
            global_4 = f32(-local_13);
            // [WAT] global.set
            global_5 = f32(-local_14);
            // [WAT] global.set
            global_6 = f32(-local_15);
            // [WAT] return
            return local_12;
          } else {
            // [WAT] global.set
            global_4 = f32(local_13);
            // [WAT] global.set
            global_5 = f32(local_14);
            // [WAT] global.set
            global_6 = f32(local_15);
            // [WAT] return
            return local_11;
          }
        }
      }
    }
  }
}

// Function 1: "func_1"
fn func_1(p0: f32, p1: f32, p2: f32, p3: f32, p4: f32, p5: f32, p6: f32, p7: f32, p8: f32, p9: f32) -> f32 {
  var local_10: f32;
  var local_11: f32;
  var local_12: f32;
  var v16: f32;
  var v21: f32;
  var v30: f32;
  var v48: f32;
  var v54: f32;
  var v55: f32;
  var v56: f32;
  var v68: f32;
  // [WAT] f32.sub
  v16 = (p0 - p6);
  // [WAT] local.set
  local_12 = v16;
  // [WAT] f32.sub
  v21 = (p1 - p7);
  // [WAT] local.set
  local_10 = v21;
  // [WAT] f32.sub
  let v27 = (p2 - p8);
  // [WAT] f32.add
  v30 = (v16 * p3 + v21 * p4 + v27 * p5);
  // [WAT] local.set
  local_11 = v30;
  // [WAT] f32.sub
  v48 = (v30 * v30 - (v16 * v16 + v21 * v21 + v27 * v27 - p9 * p9));
  // [WAT] local.set
  local_10 = v48;
  if (v48 < 0.0f) {
    // [WAT] return
    return -1.0f;
  } else {
    // [WAT] local.get
    v54 = local_10;
    // [WAT] f32.sqrt
    v55 = sqrt(v54);
    // [WAT] local.set
    local_12 = v55;
    // [WAT] f32.sub
    v56 = (-local_11 - v55);
    // [WAT] local.set
    local_10 = v56;
    if (v56 < 0.0010000000474974513f) {
      // [WAT] local.set
      local_10 = local_12 - local_11;
    }
    if (local_10 < 0.0010000000474974513f) {
      // [WAT] return
      return -1.0f;
    } else {
      // [WAT] local.get
      v68 = local_10;
      // [WAT] global.set
      global_4 = f32((p0 + p3 * v68 - p6) / p9);
      // [WAT] global.set
      global_5 = f32((p1 + p4 * v68 - p7) / p9);
      // [WAT] global.set
      global_6 = f32((p2 + p5 * v68 - p8) / p9);
      // [WAT] return
      return v68;
    }
  }
}

// Function 2: "func_2"
fn func_2(p0: f32, p1: f32, p2: f32, p3: f32, p4: f32, p5: f32) -> i32 {
  var local_0 = p0;
  var local_6: f32;
  var local_7: f32;
  var local_8: f32;
  var local_9: f32;
  var local_10: f32;
  var local_11: f32;
  var local_12: f32;
  var local_13: f32;
  var local_14: f32;
  var local_15: f32;
  var local_16: f32;
  var local_18: f32;
  var v28: f32;
  var v36: f32;
  var v40: f32;
  var v51: f32;
  var v64: f32;
  var v59: f32;
  var v35: f32;
  var v23: f32;
  var v76: f32;
  var v83: f32;
  var v110: f32;
  var v119: f32;
  var v126: f32;
  var v154: f32;
  var v163: f32;
  var v170: f32;
  var v198: f32;
  var v207: f32;
  var v243: f32;
  var v252: f32;
  var v288: f32;
  var v297: f32;
  var v304: f32;
  var v336: f32;
  var v338: f32;
  var v349: f32;
  var v365: f32;
  var v376: f32;
  var v392: f32;
  var v393: f32;
  var v403: f32;
  var v420: f32;
  var v430: f32;
  if (abs(p5) > 9.99999993922529e-9f) {
    // [WAT] f32.div
    v28 = ((3.0f - p2) / p5);
    // [WAT] local.set
    local_6 = v28;
    if ((select(0i, 1i, v28 < 100000002004087730000.0f) & select(0i, 1i, v28 > 0.0010000000474974513f)) != 0) {
      // [WAT] local.get
      v36 = local_0;
      // [WAT] local.get
      let v38 = local_6;
      // [WAT] f32.add
      v40 = (v36 + p3 * v38);
      // [WAT] local.set
      local_16 = v40;
      // [WAT] f32.add
      v51 = (p1 + p4 * v38);
      // [WAT] local.set
      local_16 = v51;
      if ((select(0i, 1i, v40 <= 1.0f) & select(0i, 1i, v40 >= -1.0f) & select(0i, 1i, v51 >= -1.0f) & select(0i, 1i, v51 <= 1.0f)) != 0) {
        // [WAT] local.set
        local_7 = -1.0f;
        // [WAT] local.set
        local_8 = 0.7300000190734863f;
        // [WAT] local.set
        local_9 = 0.7300000190734863f;
        // [WAT] local.set
        local_10 = 0.7300000190734863f;
        // [WAT] local.get
        v64 = local_6;
        // [WAT] assign
        v59 = v64;
      } else {
        // [WAT] assign
        v59 = 100000002004087730000.0f;
      }
      // [WAT] assign
      v35 = v59;
    } else {
      // [WAT] assign
      v35 = 100000002004087730000.0f;
    }
    // [WAT] assign
    v23 = v35;
  } else {
    // [WAT] assign
    v23 = 100000002004087730000.0f;
  }
  {
    // [WAT] local.set
    local_6 = v23;
    if (abs(p5) > 9.99999993922529e-9f) {
      // [WAT] f32.div
      v76 = ((-1.0f - p2) / p5);
      // [WAT] local.set
      local_16 = v76;
      // [WAT] local.get
      let v77 = local_6;
      if ((select(0i, 1i, v76 < v77) & select(0i, 1i, v76 > 0.0010000000474974513f)) != 0) {
        // [WAT] local.get
        v83 = local_0;
        // [WAT] local.get
        let v85 = local_16;
        // [WAT] f32.add
        let v87 = (v83 + p3 * v85);
        // [WAT] f32.add
        let v98 = (p1 + p4 * v85);
        if ((select(0i, 1i, v87 <= 1.0f) & select(0i, 1i, v87 >= -1.0f) & select(0i, 1i, v98 >= -1.0f) & select(0i, 1i, v98 <= 1.0f)) != 0) {
          // [WAT] local.set
          local_7 = 1.0f;
          // [WAT] local.set
          local_8 = 0.7300000190734863f;
          // [WAT] local.set
          local_9 = 0.7300000190734863f;
          // [WAT] local.set
          local_10 = 0.7300000190734863f;
          // [WAT] local.get
          v110 = local_16;
          // [WAT] local.set
          local_6 = v110;
        }
        {
        }
      }
      {
      }
    }
    {
      if (abs(p4) > 9.99999993922529e-9f) {
        // [WAT] f32.div
        v119 = ((-1.0f - p1) / p4);
        // [WAT] local.set
        local_16 = v119;
        // [WAT] local.get
        let v120 = local_6;
        if ((select(0i, 1i, v119 < v120) & select(0i, 1i, v119 > 0.0010000000474974513f)) != 0) {
          // [WAT] local.get
          v126 = local_0;
          // [WAT] local.get
          let v128 = local_16;
          // [WAT] f32.add
          let v130 = (v126 + p3 * v128);
          // [WAT] f32.add
          let v141 = (p2 + p5 * v128);
          if ((select(0i, 1i, v130 <= 1.0f) & select(0i, 1i, v130 >= -1.0f) & select(0i, 1i, v141 >= -1.0f) & select(0i, 1i, v141 <= 3.0f)) != 0) {
            // [WAT] local.set
            local_11 = 1.0f;
            // [WAT] local.set
            local_7 = 0.0f;
            // [WAT] local.set
            local_8 = 0.7300000190734863f;
            // [WAT] local.set
            local_9 = 0.7300000190734863f;
            // [WAT] local.set
            local_10 = 0.7300000190734863f;
            // [WAT] local.get
            v154 = local_16;
            // [WAT] local.set
            local_6 = v154;
          }
          {
          }
        }
        {
        }
      }
      {
        if (abs(p4) > 9.99999993922529e-9f) {
          // [WAT] f32.div
          v163 = ((1.0f - p1) / p4);
          // [WAT] local.set
          local_16 = v163;
          // [WAT] local.get
          let v164 = local_6;
          if ((select(0i, 1i, v163 < v164) & select(0i, 1i, v163 > 0.0010000000474974513f)) != 0) {
            // [WAT] local.get
            v170 = local_0;
            // [WAT] local.get
            let v172 = local_16;
            // [WAT] f32.add
            let v174 = (v170 + p3 * v172);
            // [WAT] f32.add
            let v185 = (p2 + p5 * v172);
            if ((select(0i, 1i, v174 <= 1.0f) & select(0i, 1i, v174 >= -1.0f) & select(0i, 1i, v185 >= -1.0f) & select(0i, 1i, v185 <= 3.0f)) != 0) {
              // [WAT] local.set
              local_11 = -1.0f;
              // [WAT] local.set
              local_7 = 0.0f;
              // [WAT] local.set
              local_8 = 0.7300000190734863f;
              // [WAT] local.set
              local_9 = 0.7300000190734863f;
              // [WAT] local.set
              local_10 = 0.7300000190734863f;
              // [WAT] local.get
              v198 = local_16;
              // [WAT] local.set
              local_6 = v198;
            }
            {
            }
          }
          {
          }
        }
        {
          if (abs(p3) > 9.99999993922529e-9f) {
            // [WAT] local.get
            let v204 = local_0;
            // [WAT] f32.div
            v207 = ((-1.0f - v204) / p3);
            // [WAT] local.set
            local_16 = v207;
            // [WAT] local.get
            let v208 = local_6;
            if ((select(0i, 1i, v207 < v208) & select(0i, 1i, v207 > 0.0010000000474974513f)) != 0) {
              // [WAT] local.get
              let v216 = local_16;
              // [WAT] f32.add
              let v218 = (p1 + p4 * v216);
              // [WAT] f32.add
              let v229 = (p2 + p5 * v216);
              if ((select(0i, 1i, v218 <= 1.0f) & select(0i, 1i, v218 >= -1.0f) & select(0i, 1i, v229 >= -1.0f) & select(0i, 1i, v229 <= 3.0f)) != 0) {
                // [WAT] local.set
                local_12 = 1.0f;
                // [WAT] local.set
                local_11 = 0.0f;
                // [WAT] local.set
                local_7 = 0.0f;
                // [WAT] local.set
                local_8 = 0.6499999761581421f;
                // [WAT] local.set
                local_9 = 0.05000000074505806f;
                // [WAT] local.set
                local_10 = 0.05000000074505806f;
                // [WAT] local.get
                v243 = local_16;
                // [WAT] local.set
                local_6 = v243;
              }
              {
              }
            }
            {
            }
          }
          {
            if (abs(p3) > 9.99999993922529e-9f) {
              // [WAT] local.get
              let v249 = local_0;
              // [WAT] f32.div
              v252 = ((1.0f - v249) / p3);
              // [WAT] local.set
              local_16 = v252;
              // [WAT] local.get
              let v253 = local_6;
              if ((select(0i, 1i, v252 < v253) & select(0i, 1i, v252 > 0.0010000000474974513f)) != 0) {
                // [WAT] local.get
                let v261 = local_16;
                // [WAT] f32.add
                let v263 = (p1 + p4 * v261);
                // [WAT] f32.add
                let v274 = (p2 + p5 * v261);
                if ((select(0i, 1i, v263 <= 1.0f) & select(0i, 1i, v263 >= -1.0f) & select(0i, 1i, v274 >= -1.0f) & select(0i, 1i, v274 <= 3.0f)) != 0) {
                  // [WAT] local.set
                  local_12 = -1.0f;
                  // [WAT] local.set
                  local_11 = 0.0f;
                  // [WAT] local.set
                  local_7 = 0.0f;
                  // [WAT] local.set
                  local_8 = 0.11999999731779099f;
                  // [WAT] local.set
                  local_9 = 0.44999998807907104f;
                  // [WAT] local.set
                  local_10 = 0.15000000596046448f;
                  // [WAT] local.get
                  v288 = local_16;
                  // [WAT] local.set
                  local_6 = v288;
                }
                {
                }
              }
              {
              }
            }
            {
              if (abs(p4) > 9.99999993922529e-9f) {
                // [WAT] f32.div
                v297 = ((0.9900000095367432f - p1) / p4);
                // [WAT] local.set
                local_16 = v297;
                // [WAT] local.get
                let v298 = local_6;
                if ((select(0i, 1i, v297 < v298) & select(0i, 1i, v297 > 0.0010000000474974513f)) != 0) {
                  // [WAT] local.get
                  v304 = local_0;
                  // [WAT] local.get
                  let v306 = local_16;
                  // [WAT] f32.add
                  let v308 = (v304 + p3 * v306);
                  // [WAT] f32.add
                  let v319 = (p2 + p5 * v306);
                  if ((select(0i, 1i, v308 <= 0.3499999940395355f) & select(0i, 1i, v308 >= -0.3499999940395355f) & select(0i, 1i, v319 >= 0.699999988079071f) & select(0i, 1i, v319 <= 1.399999976158142f)) != 0) {
                    // [WAT] local.set
                    local_12 = 0.0f;
                    // [WAT] local.set
                    local_11 = -1.0f;
                    // [WAT] local.set
                    local_7 = 0.0f;
                    // [WAT] local.set
                    local_8 = 0.7799999713897705f;
                    // [WAT] local.set
                    local_9 = 0.7799999713897705f;
                    // [WAT] local.set
                    local_10 = 0.7799999713897705f;
                    // [WAT] local.set
                    local_13 = 18.0f;
                    // [WAT] local.set
                    local_14 = 16.0f;
                    // [WAT] local.set
                    local_15 = 10.0f;
                    // [WAT] local.get
                    v336 = local_16;
                    // [WAT] local.set
                    local_6 = v336;
                  }
                  {
                  }
                }
                {
                }
              }
              {
                // [WAT] local.get
                let v337 = local_6;
                // [WAT] local.get
                v338 = local_0;
                // [WAT] call
                v349 = func_0(v338, p1, p2, p3, p4, p5, 0.12999999523162842f, 0.6499999761581421f, 0.7300000190734863f, 0.20000000298023224f, 1.25f);
                // [WAT] local.set
                local_18 = v349;
                if ((select(0i, 1i, v337 > v349) & select(0i, 1i, v349 > 0.0010000000474974513f)) != 0) {
                  // [WAT] local.set
                  local_12 = global_4;
                  // [WAT] local.set
                  local_11 = global_5;
                  // [WAT] local.set
                  local_7 = global_6;
                  // [WAT] local.set
                  local_8 = 0.7300000190734863f;
                  // [WAT] local.set
                  local_9 = 0.7300000190734863f;
                  // [WAT] local.set
                  local_10 = 0.7300000190734863f;
                  // [WAT] local.set
                  local_13 = 0.0f;
                  // [WAT] local.set
                  local_14 = 0.0f;
                  // [WAT] local.set
                  local_15 = 0.0f;
                  // [WAT] local.set
                  local_6 = local_18;
                }
                {
                  // [WAT] local.get
                  v365 = local_0;
                  // [WAT] call
                  v376 = func_0(v365, p1, p2, p3, p4, p5, -0.7300000190734863f, 1.100000023841858f, -0.12999999523162842f, -0.4000000059604645f, 1.7000000476837158f);
                  // [WAT] local.set
                  local_16 = v376;
                  // [WAT] local.get
                  let v377 = local_6;
                  if ((select(0i, 1i, v376 < v377) & select(0i, 1i, v376 > 0.0010000000474974513f)) != 0) {
                    // [WAT] local.set
                    local_12 = global_4;
                    // [WAT] local.set
                    local_11 = global_5;
                    // [WAT] local.set
                    local_7 = global_6;
                    // [WAT] local.set
                    local_8 = 0.7300000190734863f;
                    // [WAT] local.set
                    local_9 = 0.7300000190734863f;
                    // [WAT] local.set
                    local_10 = 0.7300000190734863f;
                    // [WAT] local.set
                    local_13 = 0.0f;
                    // [WAT] local.set
                    local_14 = 0.0f;
                    // [WAT] local.set
                    local_15 = 0.0f;
                    // [WAT] local.get
                    v392 = local_16;
                    // [WAT] local.set
                    local_6 = v392;
                  }
                  {
                    // [WAT] local.get
                    v393 = local_0;
                    // [WAT] call
                    v403 = func_1(v393, p1, p2, p3, p4, p5, -0.4300000071525574f, -0.6499999761581421f, 1.399999976158142f, 0.3499999940395355f);
                    // [WAT] local.set
                    local_16 = v403;
                    // [WAT] local.get
                    let v404 = local_6;
                    if ((select(0i, 1i, v403 < v404) & select(0i, 1i, v403 > 0.0010000000474974513f)) != 0) {
                      // [WAT] local.set
                      local_12 = global_4;
                      // [WAT] local.set
                      local_11 = global_5;
                      // [WAT] local.set
                      local_7 = global_6;
                      // [WAT] local.set
                      local_8 = 0.8999999761581421f;
                      // [WAT] local.set
                      local_9 = 0.8999999761581421f;
                      // [WAT] local.set
                      local_10 = 0.949999988079071f;
                      // [WAT] local.set
                      local_13 = 0.0f;
                      // [WAT] local.set
                      local_14 = 0.0f;
                      // [WAT] local.set
                      local_15 = 0.0f;
                      // [WAT] local.set
                      local_6 = local_16;
                    }
                    {
                      // [WAT] local.get
                      v420 = local_0;
                      // [WAT] call
                      v430 = func_1(v420, p1, p2, p3, p4, p5, 0.4300000071525574f, 0.44999998807907104f, 0.949999988079071f, 0.25f);
                      // [WAT] local.set
                      local_0 = v430;
                      // [WAT] local.get
                      let v431 = local_6;
                      if ((select(0i, 1i, v430 < v431) & select(0i, 1i, v430 > 0.0010000000474974513f)) != 0) {
                        // [WAT] local.set
                        local_12 = global_4;
                        // [WAT] local.set
                        local_11 = global_5;
                        // [WAT] local.set
                        local_7 = global_6;
                        // [WAT] local.set
                        local_8 = 0.949999988079071f;
                        // [WAT] local.set
                        local_9 = 0.75f;
                        // [WAT] local.set
                        local_10 = 0.4000000059604645f;
                        // [WAT] local.set
                        local_13 = 0.0f;
                        // [WAT] local.set
                        local_14 = 0.0f;
                        // [WAT] local.set
                        local_15 = 0.0f;
                        // [WAT] local.set
                        local_6 = local_0;
                      }
                      if (local_6 >= 100000002004087730000.0f) {
                        // [WAT] return
                        return 0i;
                      } else {
                        // [WAT] global.set
                        global_7 = f32(local_6);
                        // [WAT] global.set
                        global_8 = f32(local_12);
                        // [WAT] global.set
                        global_9 = f32(local_11);
                        // [WAT] global.set
                        global_10 = f32(local_7);
                        // [WAT] global.set
                        global_11 = f32(local_8);
                        // [WAT] global.set
                        global_12 = f32(local_9);
                        // [WAT] global.set
                        global_13 = f32(local_10);
                        // [WAT] global.set
                        global_14 = f32(local_13);
                        // [WAT] global.set
                        global_15 = f32(local_14);
                        // [WAT] global.set
                        global_16 = f32(local_15);
                        // [WAT] return
                        return 1i;
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

// Function 3: "func_3"
fn func_3(p0: f32, p1: f32, p2: f32) {
  var local_3: f32;
  var local_4: f32;
  var local_5: f32;
  var local_6: f32;
  var local_7: f32;
  var local_8: f32;
  var local_9: f32;
  var local_10: f32;
  var local_11: f32;
  var v60: f32;
  var v80: f32;
  var v69: f32;
  var v97: f32;
  var v109: f32;
  var v118: f32;
  var v133: f32;
  var v137: f32;
  var v153: f32;
  var v155: f32;
  var v164: f32;
  var v179: f32;
  var v183: f32;
  var v199: f32;
  var v206: f32;
  // [WAT] global.set — First RNG call (produces r1)
  global_0 = global_0 * 747796405i - 1403630843i;
  // [WAT] i32.mul
  let v28 = ((global_0 ^ bitcast<i32>(bitcast<u32>(global_0) >> (bitcast<u32>(bitcast<i32>(bitcast<u32>(global_0) >> 28u) + 4i) & 31u))) * 277803737i);
  // [WAT] global.set
  global_0 = v28 ^ bitcast<i32>(bitcast<u32>(v28) >> 22u);
  // [FIX] Capture r1 before second RNG call overwrites global_0
  let r1 = f32(bitcast<u32>(global_0)) * 2.3283064365386963e-10f;
  // [WAT] global.set — Second RNG call (produces r2)
  global_0 = global_0 * 747796405i - 1403630843i;
  // [WAT] i32.mul
  let v52 = ((global_0 ^ bitcast<i32>(bitcast<u32>(global_0) >> (bitcast<u32>(bitcast<i32>(bitcast<u32>(global_0) >> 28u) + 4i) & 31u))) * 277803737i);
  // [WAT] global.set
  global_0 = v52 ^ bitcast<i32>(bitcast<u32>(v52) >> 22u);
  // [WAT] f32.mul — r2 from second RNG call
  v60 = (f32(bitcast<u32>(global_0)) * 2.3283064365386963e-10f);
  // [WAT] local.set
  local_9 = v60;
  // [WAT] local.set
  local_4 = sqrt(v60);
  // [FIX] phi = TWO_PI * r1 (was incorrectly using r2 via global_0)
  local_10 = r1 * 6.2831854820251465f;
  if (abs(p1) > 0.8999999761581421f) {
    // [WAT] f32.div
    v80 = (1.0f / sqrt(p2 * p2 + p1 * p1));
    // [WAT] local.set
    local_3 = v80;
    // [WAT] local.set
    local_6 = p2 * v80;
    // [WAT] assign
    v69 = -p1 * v80;
  } else {
    // [WAT] f32.div
    v97 = (1.0f / sqrt(p2 * p2 + p0 * p0));
    // [WAT] local.set
    local_3 = v97;
    // [WAT] local.set
    local_5 = -p2 * v97;
    // [WAT] assign
    v69 = p0 * v97;
  }
  {
    // [WAT] local.set
    local_8 = v69;
    // [WAT] local.set
    local_7 = p1 * v69 - p2 * local_6;
    // [WAT] f32.add
    v109 = (local_10 + 1.5707963705062866f);
    // [WAT] local.set
    local_3 = v109;
    // [WAT] f32.sub
    v118 = (v109 - floor(v109 / 6.2831854820251465f + 0.5f) * 6.2831854820251465f);
    // [WAT] local.set
    local_3 = v118;
    if (v118 > 1.5707963705062866f) {
      // [WAT] local.get
      let v122 = local_3;
      // [WAT] local.set
      local_3 = 3.1415927410125732f - v122;
    }
    {
      // [WAT] local.get
      let v124 = local_3;
      if (v124 < -1.5707963705062866f) {
        // [WAT] local.get
        let v128 = local_3;
        // [WAT] local.set
        local_3 = -3.1415927410125732f - v128;
      }
      {
        // [WAT] local.get
        v133 = local_3;
        // [WAT] f32.mul
        v137 = (v133 * v133);
        // [WAT] local.set
        local_3 = v137;
        // [WAT] f32.mul
        v153 = (v133 * (1.0f - v137 / 6.0f * (1.0f - v137 / 20.0f * (1.0f - v137 / 42.0f))));
        // [WAT] local.set
        local_11 = v153;
        // [WAT] local.get
        v155 = local_10;
        // [WAT] f32.sub
        v164 = (v155 - floor(v155 / 6.2831854820251465f + 0.5f) * 6.2831854820251465f);
        // [WAT] local.set
        local_3 = v164;
        if (v164 > 1.5707963705062866f) {
          // [WAT] local.get
          let v168 = local_3;
          // [WAT] local.set
          local_3 = 3.1415927410125732f - v168;
        }
        {
          // [WAT] local.get
          let v170 = local_3;
          if (v170 < -1.5707963705062866f) {
            // [WAT] local.get
            let v174 = local_3;
            // [WAT] local.set
            local_3 = -3.1415927410125732f - v174;
          }
          // [WAT] local.get
          let v176 = local_7;
          // [WAT] local.get
          let v177 = local_4;
          // [WAT] local.get
          v179 = local_3;
          // [WAT] f32.mul
          v183 = (v179 * v179);
          // [WAT] local.set
          local_3 = v183;
          // [WAT] f32.mul
          v199 = (v179 * (1.0f - v183 / 6.0f * (1.0f - v183 / 20.0f * (1.0f - v183 / 42.0f))));
          // [WAT] local.set
          local_3 = v199;
          // [WAT] f32.sqrt
          v206 = sqrt(1.0f - local_9);
          // [WAT] local.set
          local_7 = v206;
          // [WAT] global.set
          global_1 = f32(local_5 * local_4 * v153 + v176 * v177 * v199 + p0 * v206);
          // [WAT] local.get
          let v209 = local_6;
          // [WAT] local.get
          let v212 = local_11;
          // [WAT] local.get
          let v215 = local_5;
          // [WAT] local.get
          let v218 = local_8;
          // [WAT] global.set
          global_2 = f32(v209 * v177 * v212 + (p2 * v215 - p0 * v218) * v177 * v199 + p1 * v206);
          // [WAT] global.set
          global_3 = f32(v218 * v177 * v212 + (p0 * v209 - p1 * v215) * v177 * v199 + p2 * v206);
          // [WAT] return
          return;
        }
      }
    }
  }
}

// Function 4: "func_4"
fn func_4(p0: f32) -> f32 {
  var local_0 = p0;
  var local_1: i32;
  var local_2: i32;
  var local_4: f32;
  var v14: f32;
  var v40: f32;
  var v62: f32;
  var v9: f32;
  var v69: f32;
  var v73: f32;
  var v76: f32;
  var v95: i32;
  // [WAT] local.get
  let v5 = local_0;
  if (v5 <= 0.0f) {
    // [WAT] return
    return 0.0f;
  } else {
    // [WAT] local.get
    let v11 = local_0;
    if (v11 <= 0.0f) {
      // [WAT] assign
      v14 = -100.0f;
    } else {
      // [LOOP] loop_9
      loop {
        // [WAT] local.get
        let v16 = local_0;
        if (v16 >= 2.0f) {
          // [WAT] local.get
          let v19 = local_0;
          // [WAT] local.set
          local_0 = v19 * 0.5f;
          // [WAT] local.get
          let v22 = local_1;
          // [WAT] local.set
          local_1 = v22 + 1i;
          continue;
        } else {
          break;
        }
      }
      // End: loop_9
      {
        // [LOOP] loop_14
        loop {
          // [WAT] local.get
          let v25 = local_0;
          if (v25 < 1.0f) {
            // [WAT] local.get
            let v28 = local_0;
            // [WAT] local.set
            local_0 = v28 + v28;
            // [WAT] local.get
            let v31 = local_1;
            // [WAT] local.set
            local_1 = v31 - 1i;
            continue;
          } else {
            break;
          }
        }
        // End: loop_14
        // [LOOP]
        loop {
          {
            // [WAT] local.get
            let v34 = local_0;
            // [WAT] f32.div
            v40 = ((v34 + -1.0f) / (v34 + 1.0f));
            // [WAT] local.set
            local_0 = v40;
            // [WAT] f32.mul
            let v42 = (v40 * v40);
            // [WAT] local.get
            let v43 = local_1;
            // [WAT] assign
            v14 = f32(v43) * 0.6931471824645996f + (v40 + v40) * (v42 * (v42 * 0.20000000298023224f + 0.3333333134651184f) + 1.0f);
            break;
          }
        }
      }
    }
    {
      // [WAT] f32.mul
      v62 = (v14 * 0.4544999897480011f);
      // [WAT] local.set
      local_0 = v62;
      if (v62 < -20.0f) {
        // [WAT] assign
        v9 = 0.0f;
      } else {
        // [WAT] local.get
        let v66 = local_0;
        if (v66 > 20.0f) {
          // [WAT] assign
          v9 = 485165184.0f;
        } else {
          // [WAT] local.get
          v69 = local_0;
          // [WAT] f32.floor
          v73 = floor(v69 * 1.4426950216293335f);
          // [WAT] f32.sub
          v76 = (v69 - v73 * 0.6931471824645996f);
          // [WAT] local.set
          local_0 = v76;
          // [WAT] local.set
          local_4 = v76 * (v76 * (v76 * (v76 * 0.0416666716337204f + 0.16666670143604279f) + 0.5f) + 1.0f) + 1.0f;
          // [WAT] local.set
          local_0 = 1.0f;
          // [WAT] i32.trunc_sat_f32_s
          v95 = i32(trunc(v73));
          // [WAT] local.set
          local_1 = v95;
          if (v95 > 0i) {
            // [LOOP] loop_26
            loop {
              // [WAT] local.get
              let v99 = local_2;
              if (local_1 > v99) {
                // [WAT] local.get
                let v101 = local_0;
                // [WAT] local.set
                local_0 = v101 + v101;
                // [WAT] local.get
                let v104 = local_2;
                // [WAT] local.set
                local_2 = v104 + 1i;
                continue;
              } else {
                break;
              }
            }
            // End: loop_26
            // [LOOP]
            loop {
              break;
            }
          } else {
            // [WAT] local.get
            let v108 = local_1;
            // [WAT] local.set
            local_1 = 0i - v108;
            {
              // [LOOP] loop_31
              loop {
                // [WAT] local.get
                let v111 = local_2;
                if (local_1 > v111) {
                  // [WAT] local.get
                  let v113 = local_0;
                  // [WAT] local.set
                  local_0 = v113 * 0.5f;
                  // [WAT] local.get
                  let v116 = local_2;
                  // [WAT] local.set
                  local_2 = v116 + 1i;
                  continue;
                } else {
                  break;
                }
              }
              // End: loop_31
              // [LOOP]
              loop {
                break;
              }
            }
          }
          // [WAT] assign
          v9 = local_0 * local_4;
        }
      }
      // [WAT] return
      return v9;
    }
  }
}

// Function 5: "main"
fn func_5() {
  var local_0: f32;
  var local_1: f32;
  var local_2: f32;
  var local_3: f32;
  var local_4: f32;
  var local_5: f32;
  var local_6: f32;
  var local_7: f32;
  var local_8: f32;
  var local_9: f32;
  var local_10: f32;
  var local_11: f32;
  var local_12: f32;
  var local_13: f32;
  var local_14: f32;
  var local_15: f32;
  var local_18: i32;
  var local_19: i32;
  var local_20: i32;
  var local_21: i32;
  var local_22: i32;
  var local_23: i32;
  var v31: i32;
  var v33: i32;
  var v38: i32;
  var v63: i32;
  var v83: i32;
  var v118: i32;
  var v137: f32;
  var v153: i32;
  var v177: f32;
  var v183: f32;
  var v195: f32;
  var v196: f32;
  var v197: f32;
  var v198: f32;
  var v199: f32;
  var v200: f32;
  var v260: f32;
  var v261: f32;
  var v269: f32;
  var v270: f32;
  var v283: f32;
  var v287: f32;
  var v316: f32;
  var v317: f32;
  var v318: f32;
  var v331: f32;
  var v333: f32;
  var v338: f32;
  var v339: f32;
  var v341: f32;
  var v346: f32;
  var v347: f32;
  var v349: f32;
  var v354: f32;
  var v355: i32;
  var v357: i32;
  var v407: u32;
  var v409: i32;
  var v411: u32;
  var v413: i32;
  var v415: u32;
  // [WAT] i32.const
  // [WAT] i32.const
  // [WAT] wgsl.load_f32
  let v26 = wgsl_load_f32(0u);
  // [WAT] local.set
  local_21 = i32(trunc(v26));
  {
    // [PARALLEL] Loop parallelized: 65536 work items
    if (_wgpu_global_idx < 65536u) {
      // [WAT] local.get
      let v28 = i32(_wgpu_global_idx);
      if (v28 < 65536i) {
        // [WAT] local.get
        v31 = i32(_wgpu_global_idx);
        // [WAT] i32.sub
        v33 = (v31 - (((v31 + ((v31 >> 31u) & 255i)) >> 8u) << 8u));
        // [WAT] local.set
        local_22 = v33;
        // [WAT] i32.shr_s
        v38 = ((v31 + ((v31 >> 31u) & 255i)) >> 8u);
        // [WAT] local.set
        local_23 = v38;
        // [WAT] global.set
        global_0 = (v33 * 1973i + v38 * 9277i + local_21 * 26699i) | 1i;
        // [WAT] global.set
        global_0 = global_0 * 747796405i - 1403630843i;
        // [WAT] i32.mul
        v63 = ((global_0 ^ bitcast<i32>(bitcast<u32>(global_0) >> (bitcast<u32>(bitcast<i32>(bitcast<u32>(global_0) >> 28u) + 4i) & 31u))) * 277803737i);
        // [WAT] local.set
        local_19 = v63;
        // [WAT] global.set
        global_0 = bitcast<i32>(bitcast<u32>(v63) >> 22u) ^ v63;
        // [WAT] global.set
        global_0 = global_0 * 747796405i - 1403630843i;
        // [WAT] i32.mul
        v83 = ((global_0 ^ bitcast<i32>(bitcast<u32>(global_0) >> (bitcast<u32>(bitcast<i32>(bitcast<u32>(global_0) >> 28u) + 4i) & 31u))) * 277803737i);
        // [WAT] local.set
        local_19 = v83;
        // [WAT] global.set
        global_0 = bitcast<i32>(bitcast<u32>(v83) >> 22u) ^ v83;
        // [WAT] local.set
        local_7 = 0.0f;
        // [WAT] local.set
        local_8 = 0.0f;
        // [WAT] local.set
        local_9 = 0.0f;
        // [WAT] local.set
        local_20 = 0i;
        {
          // [LOOP] loop_6
          loop {
            // [WAT] local.get
            let v92 = local_20;
            if (v92 < 100i) {
              // [WAT] local.set
              local_10 = 0.0f;
              // [WAT] local.set
              local_11 = 0.0f;
              // [WAT] local.set
              local_12 = 0.0f;
              // [WAT] local.set
              local_2 = 1.0f;
              // [WAT] local.set
              local_0 = 1.0f;
              // [WAT] local.set
              local_3 = 0.0f;
              // [WAT] local.set
              local_4 = 0.0f;
              // [WAT] local.set
              local_5 = -0.8999999761581421f;
              // [WAT] global.set
              global_0 = global_0 * 747796405i - 1403630843i;
              // [WAT] i32.mul
              v118 = ((global_0 ^ bitcast<i32>(bitcast<u32>(global_0) >> (bitcast<u32>(bitcast<i32>(bitcast<u32>(global_0) >> 28u) + 4i) & 31u))) * 277803737i);
              // [WAT] local.set
              local_19 = v118;
              // [WAT] global.set
              global_0 = bitcast<i32>(bitcast<u32>(v118) >> 22u) ^ v118;
              // [WAT] local.get
              let v123 = local_22;
              // [WAT] f32.mul
              v137 = (((f32(v123) + f32(bitcast<u32>(global_0)) * 2.3283064365386963e-10f) * 2.0f * 0.00390625f + -1.0f) * 1.2000000476837158f);
              // [WAT] local.set
              local_1 = v137;
              // [WAT] global.set
              global_0 = global_0 * 747796405i - 1403630843i;
              // [WAT] i32.mul
              v153 = ((global_0 ^ bitcast<i32>(bitcast<u32>(global_0) >> (bitcast<u32>(bitcast<i32>(bitcast<u32>(global_0) >> 28u) + 4i) & 31u))) * 277803737i);
              // [WAT] local.set
              local_19 = v153;
              // [WAT] global.set
              global_0 = bitcast<i32>(bitcast<u32>(v153) >> 22u) ^ v153;
              // [WAT] local.set
              local_6 = 1.0f;
              // [WAT] local.get
              let v163 = local_23;
              // [WAT] f32.mul
              v177 = (((f32(v163) + f32(bitcast<u32>(global_0)) * 2.3283064365386963e-10f) * 2.0f * 0.00390625f + -1.0f) * -1.2000000476837158f);
              // [WAT] local.set
              local_1 = v177;
              // [WAT] f32.sqrt
              v183 = sqrt(v137 * v137 + v177 * v177 + 1.0f);
              // [WAT] local.set
              local_15 = v183;
              // [WAT] local.set
              local_13 = v137 / v183;
              // [WAT] local.set
              local_14 = v177 / v183;
              // [WAT] local.set
              local_1 = 1.0f / v183;
              // [WAT] local.set
              local_19 = 0i;
              {
                // [LOOP] loop_11
                loop {
                  // [WAT] local.get
                  let v192 = local_19;
                  if (v192 < 5i) {
                    // [WAT] local.get
                    v195 = local_3;
                    // [WAT] local.get
                    v196 = local_4;
                    // [WAT] local.get
                    v197 = local_5;
                    // [WAT] local.get
                    v198 = local_13;
                    // [WAT] local.get
                    v199 = local_14;
                    // [WAT] local.get
                    v200 = local_1;
                    // [WAT] call
                    let v201 = func_2(v195, v196, v197, v198, v199, v200);
                    if (v201 == 0i) {
                      break;
                    }
                    {
                      // [WAT] local.get
                      let v203 = local_10;
                      // [WAT] local.get
                      let v204 = local_6;
                      // [WAT] local.set
                      local_10 = v203 + v204 * global_14;
                      // [WAT] local.get
                      let v208 = local_11;
                      // [WAT] local.get
                      let v209 = local_2;
                      // [WAT] local.set
                      local_11 = v208 + v209 * global_15;
                      // [WAT] local.get
                      let v213 = local_12;
                      // [WAT] local.get
                      let v214 = local_0;
                      // [WAT] local.set
                      local_12 = v213 + v214 * global_16;
                      if (global_14 + global_15 + global_16 > 0.0f) {
                        break;
                      }
                      {
                        // [WAT] local.get
                        let v225 = local_6;
                        // [WAT] local.set
                        local_6 = v225 * global_11;
                        // [WAT] local.get
                        let v228 = local_2;
                        // [WAT] local.set
                        local_2 = v228 * global_12;
                        // [WAT] local.get
                        let v231 = local_0;
                        // [WAT] local.set
                        local_0 = v231 * global_13;
                        // [WAT] local.get
                        let v234 = local_19;
                        if (v234 > 1i) {
                          // [WAT] global.set
                          global_0 = global_0 * 747796405i - 1403630843i;
                          // [WAT] i32.mul
                          let v252 = ((global_0 ^ bitcast<i32>(bitcast<u32>(global_0) >> (bitcast<u32>(bitcast<i32>(bitcast<u32>(global_0) >> 28u) + 4i) & 31u))) * 277803737i);
                          // [WAT] global.set
                          global_0 = bitcast<i32>(bitcast<u32>(v252) >> 22u) ^ v252;
                          // [WAT] local.get
                          let v257 = local_0;
                          // [WAT] local.get
                          let v258 = local_2;
                          // [WAT] local.get
                          v260 = local_6;
                          // [WAT] f32.max
                          v261 = max(max(v257, v258), v260);
                          // [WAT] local.set
                          local_15 = v261;
                          if (v261 < f32(bitcast<u32>(global_0)) * 2.3283064365386963e-10f) {
                            break;
                          }
                          // [WAT] local.get
                          let v267 = local_6;
                          // [WAT] local.get
                          v269 = local_15;
                          // [WAT] f32.div
                          v270 = (1.0f / v269);
                          // [WAT] local.set
                          local_15 = v270;
                          // [WAT] local.set
                          local_6 = v267 * v270;
                          // [WAT] local.get
                          let v272 = local_2;
                          // [WAT] local.set
                          local_2 = v272 * v270;
                          // [WAT] local.get
                          let v275 = local_0;
                          // [WAT] local.set
                          local_0 = v275 * v270;
                        }
                        {
                          // [WAT] local.get
                          let v278 = local_3;
                          // [WAT] local.get
                          let v279 = local_13;
                          // [WAT] local.get
                          v283 = local_4;
                          // [WAT] local.get
                          let v284 = local_14;
                          // [WAT] f32.add
                          v287 = (v283 + v284 * global_7);
                          // [WAT] local.set
                          local_15 = v287;
                          // [WAT] local.get
                          let v288 = local_5;
                          // [WAT] local.get
                          let v289 = local_1;
                          // [WAT] local.set
                          local_4 = global_9;
                          // [WAT] local.set
                          local_5 = global_10;
                          // [WAT] call
                          func_3(global_8, global_9, global_10);
                          // [WAT] local.set
                          local_13 = global_1;
                          // [WAT] local.set
                          local_14 = global_2;
                          // [WAT] local.set
                          local_1 = global_3;
                          // [WAT] local.set
                          local_3 = v278 + v279 * global_7 + global_8 * 0.0010000000474974513f;
                          // [WAT] local.set
                          local_4 = v287 + global_9 * 0.0010000000474974513f;
                          // [WAT] local.set
                          local_5 = v288 + v289 * global_7 + global_10 * 0.0010000000474974513f;
                          // [WAT] local.get
                          let v313 = local_19;
                          // [WAT] local.set
                          local_19 = v313 + 1i;
                          continue;
                        }
                      }
                    }
                  } else {
                    break;
                  }
                }
                // End: loop_11
                {
                  // [WAT] local.get
                  v316 = local_10;
                  // [WAT] global.set
                  global_17 = f32(v316);
                  // [WAT] local.get
                  v317 = local_11;
                  // [WAT] global.set
                  global_18 = f32(v317);
                  // [WAT] local.get
                  v318 = local_12;
                  // [WAT] global.set
                  global_19 = f32(v318);
                  // [WAT] local.get
                  let v319 = local_7;
                  // [WAT] local.set
                  local_7 = v319 + global_17;
                  // [WAT] local.get
                  let v322 = local_8;
                  // [WAT] local.set
                  local_8 = v322 + global_18;
                  // [WAT] local.get
                  let v325 = local_9;
                  // [WAT] local.set
                  local_9 = v325 + global_19;
                  // [WAT] local.get
                  let v328 = local_20;
                  // [WAT] local.set
                  local_20 = v328 + 1i;
                  continue;
                }
              }
            } else {
              break;
            }
          }
          // End: loop_6
          {
            // [WAT] local.get
            v331 = local_7;
            // [WAT] f32.mul
            v333 = (v331 * 0.009999999776482582f);
            // [WAT] local.set
            local_0 = v333;
            // [WAT] call
            v338 = func_4(v333 / (v333 + 1.0f));
            // [WAT] local.set
            local_0 = v338;
            // [WAT] local.get
            v339 = local_8;
            // [WAT] f32.mul
            v341 = (v339 * 0.009999999776482582f);
            // [WAT] local.set
            local_1 = v341;
            // [WAT] call
            v346 = func_4(v341 / (v341 + 1.0f));
            // [WAT] local.set
            local_1 = v346;
            // [WAT] local.get
            v347 = local_9;
            // [WAT] f32.mul
            v349 = (v347 * 0.009999999776482582f);
            // [WAT] local.set
            local_2 = v349;
            // [WAT] call
            v354 = func_4(v349 / (v349 + 1.0f));
            // [WAT] local.set
            local_2 = v354;
            // [WAT] local.get
            v355 = i32(_wgpu_global_idx);
            // [WAT] i32.mul
            v357 = (v355 * 12i);
            // [WAT] local.set
            local_19 = v357;
            // [WAT] i32.shr_u
            v407 = (bitcast<u32>((v357 + 16i)) >> 2u);
            // [WAT] wgsl.store_i32
            wgsl_store_i32(v407, i32(trunc(min(max(v338, 0.0f), 1.0f) * 255.0f)));
            // [WAT] i32.const
            // [WAT] i32.add
            v409 = (v357 + 20i);
            // [WAT] i32.shr_u
            v411 = (bitcast<u32>(v409) >> 2u);
            // [WAT] wgsl.store_i32
            wgsl_store_i32(v411, i32(trunc(min(max(v346, 0.0f), 1.0f) * 255.0f)));
            // [WAT] i32.const
            // [WAT] i32.add
            v413 = (v357 + 24i);
            // [WAT] i32.shr_u
            v415 = (bitcast<u32>(v413) >> 2u);
            // [WAT] wgsl.store_i32
            wgsl_store_i32(v415, i32(trunc(min(max(v354, 0.0f), 1.0f) * 255.0f)));
            // [WAT] local.set
            local_18 = v355 + 1i;
            // continue (parallelized - no-op)
          }
        }
      } else {
        // break (parallelized - no-op, guard condition handles bounds)
      }
    }
    // [PARALLEL] Epilogue: runs on single invocation
    if (_wgpu_global_idx == 0u) {
      // [WAT] return
      return;
    }
  }
}

@compute @workgroup_size(64, 1, 1)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>, @builtin(local_invocation_id) local_id: vec3<u32>, @builtin(workgroup_id) workgroup_id: vec3<u32>, @builtin(num_workgroups) num_workgroups: vec3<u32>) {
  _wgpu_global_idx = global_id.x;
  func_5();
}
