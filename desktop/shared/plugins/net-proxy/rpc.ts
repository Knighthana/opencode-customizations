/**
 * RPC contract between the net-proxy server part and its GUI.
 *
 * The GUI cannot import this file (its bundle is plain CommonJS), so it declares
 * the same contract by id. Tokens are matched by id, not by module identity.
 *
 * Schemas use Effect Schema because the RPC validators in this build do not
 * accept raw JSON Schema.
 */

import { Rpc } from "@opencode/plugin/rpc"
import { Schema } from "effect"

export const Status = Schema.Struct({
  mode: Schema.String,
  upstream: Schema.String,
  effective: Schema.String,
  available: Schema.Boolean,
})

export const NetProxy = Rpc.define({
  id: "net-proxy",
  methods: {
    status: {
      input: Schema.Struct({}),
      output: Status,
      errors: {},
    },
    set: {
      input: Schema.Struct({
        mode: Schema.String,
        upstream: Schema.optional(Schema.String),
      }),
      output: Status,
      errors: {},
    },
  },
  events: {
    changed: {
      schema: Status,
    },
  },
})
