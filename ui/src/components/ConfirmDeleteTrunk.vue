<!--
  Copyright (C) 2025 Nethesis S.r.l.
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <NsModal
    kind="danger"
    size="default"
    :visible="isShown"
    @modal-hidden="$emit('hide')"
    @primary-click="$emit('confirm')"
  >
    <template slot="title"
      >{{ $t("trunks.delete_trunk") }}: {{ trunk.rule }}</template
    >
    <template slot="content">
      <div>{{ $t("trunks.confirm_delete_trunk_message") }}</div>
    </template>
    <template slot="secondary-button">{{ core.$t("common.cancel") }}</template>
    <template slot="primary-button">{{ core.$t("common.delete") }}</template>
  </NsModal>
</template>

<script>
import { UtilService, IconService } from "@nethserver/ns8-ui-lib";
export default {
  name: "ConfirmDeleteTrunk",
  mixins: [UtilService, IconService],
  props: {
    isShown: Boolean,
    trunk: { type: [Object, null] },
    core: { type: Object },
  },
};
</script>

<style scoped lang="scss">
@import "../styles/carbon-utils";
</style>
