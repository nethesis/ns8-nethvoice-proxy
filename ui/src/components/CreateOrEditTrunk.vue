<!--
  Copyright (C) 2025 Nethesis S.r.l.
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <NsModal
    size="default"
    :visible="isShown"
    @modal-hidden="onModalHidden"
    @primary-click="createTrunk"
    :primary-button-disabled="loading.createTrunk"
  >
    <template slot="title">{{
      !isEdit
        ? $t("trunks.create_trunk") + " "
        : $t("trunks.edit_trunk") + " " + trunk.rule
    }}</template>
    <template slot="content">
      <cv-form>
        <cv-row v-if="error.createTrunk">
          <cv-column>
            <NsInlineNotification
              kind="error"
              :title="$t('trunks.create_trunk')"
              :description="error.createTrunk"
              :showCloseButton="false"
            />
          </cv-column>
        </cv-row>
        <cv-row>
          <cv-column>
            <p class="mg-bottom-sm">
              {{ $t("trunks.configure_trunk_description") }}
            </p>
          </cv-column>
        </cv-row>
        <NsTextInput
          class="mg-left"
          v-model.trim="rule"
          :label="$t('trunks.root')"
          ref="rule"
          :invalid-message="$t(error.rule)"
          :disabled="loading.createTrunk || isEdit"
          :helper-text="$t('trunks.root_helper')"
        />
        <NsComboBox
          class="max-dropdown-width mg-bottom mg-left"
          :options="sip_providers"
          v-model.trim="destination"
          :autoFilter="true"
          :autoHighlight="true"
          :title="$t('trunks.destination_instance')"
          :label="$t('trunks.destination_instance')"
          :userInputLabel="$t('trunks.destination_instance')"
          :acceptUserInput="false"
          :showItemType="true"
          :invalid-message="$t(error.destination)"
          tooltipAlignment="start"
          tooltipDirection="top"
          :disabled="loading.createTrunk"
          ref="destination"
        >
          <template slot="tooltip">
            {{ $t("trunks.choose_the_destination_instance") }}
          </template>
        </NsComboBox>
      </cv-form>
      <cv-row v-if="error.createTrunk">
        <cv-column>
          <NsInlineNotification
            kind="error"
            :title="$t('trunks.create_trunk')"
            :description="error.createTrunk"
            :showCloseButton="false"
          />
        </cv-column>
      </cv-row>
    </template>
    <template slot="secondary-button">{{ $t("common.cancel") }}</template>
    <template slot="primary-button">{{ $t("common.save") }}</template>
  </NsModal>
</template>

<script>
import to from "await-to-js";
import { UtilService, TaskService } from "@nethserver/ns8-ui-lib";
import { mapState } from "vuex";
export default {
  name: "CreateOrEditTrunk",
  mixins: [UtilService, TaskService],
  props: {
    isShown: Boolean,
    isEdit: Boolean,
    trunk: { type: [Object, null] },
    sip_providers: { type: Array },
    rule_names: { type: Array },
  },
  components: {},
  data() {
    return {
      isValidated: false,
      loading: {
        createTrunk: false,
      },
      rule: "",
      destination: "",
      error: {
        rule: "",
        destination: "",
      },
    };
  },
  computed: {
    ...mapState(["instanceName", "core", "appName"]),
  },
  watch: {
    isShown: function () {
      if (this.isShown) {
        this.clearErrors();
        this.rule = this.trunk.rule;
        this.destination = this.trunk.destination
          ? this.trunk.destination.description +
            "," +
            this.trunk.destination.uri
          : "";
      } else {
        // hiding modal
        this.clearErrors();
        this.clearFields();
      }
    },
  },
  methods: {
    clearFields() {
      this.rule = "";
      this.destination = "";
    },
    validateConfigureModule() {
      this.clearErrors(this);

      let isValidationOk = true;
      // validate rule
      if (!this.rule) {
        this.error.rule = "common.required";
        if (isValidationOk) {
          this.focusElement("rule");
        }
        isValidationOk = false;
      }
      // validate rule is alphanumeric
      const ruleRegex = /^[0-9a-zA-Z]+$/;
      if (this.rule && !ruleRegex.test(this.rule)) {
        this.error.rule = "trunks.root_invalid_alphanumeric_format";
        if (isValidationOk) {
          this.focusElement("rule");
        }
        isValidationOk = false;
      }
      // validate rule is unique
      if (!this.isEdit && this.rule && this.rule_names.includes(this.rule)) {
        this.error.rule = "trunks.root_already_exists";
        if (isValidationOk) {
          this.focusElement("rule");
        }
        isValidationOk = false;
      }
      // validate destination
      if (!this.destination) {
        this.error.destination = "common.required";

        if (isValidationOk) {
          this.focusElement("destination");
        }
        isValidationOk = false;
      }
      return isValidationOk;
    },
    createTrunkValidationFailed(validationErrors) {
      this.loading.createTrunk = false;
      let focusAlreadySet = false;
      for (const validationError of validationErrors) {
        const param = validationError.parameter;
        // set i18n error message
        this.error[param] = this.$t("trunks." + validationError.error);
        if (!focusAlreadySet) {
          this.focusElement(param);
          focusAlreadySet = true;
        }
      }
    },
    async createTrunk() {
      const isValidationOk = this.validateConfigureModule();
      if (!isValidationOk) {
        return;
      }
      this.loading.createTrunk = true;
      this.error.createTrunk = false;
      const taskAction = "add-trunk";
      const eventId = this.getUuid();
      // register to trunk error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.setCreateTrunkAborted
      );
      // register to trunk validation
      this.core.$root.$once(
        `${taskAction}-validation-failed-${eventId}`,
        this.createTrunkValidationFailed
      );
      // register to trunk completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.setCreateTrunkCompleted
      );
      const description = this.destination.split(",")[0];
      const uri = this.destination.split(",")[1];
      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          data: {
            rule: this.rule.toLowerCase(),
            destination: {
              uri: uri,
              description: description,
            },
          },
          extra: {
            title: this.isEdit
              ? this.$t("action.edit-trunk")
              : this.$t("action.add-trunk"),
            isNotificationHidden: false,
            eventId,
          },
        })
      );
      const err = res[0];
      if (err) {
        console.error(`error creating trunk ${taskAction}`, err);
        this.error.createTrunk = this.getErrorMessage(err);
        this.loading.createTrunk = false;
        return;
      }
    },
    setCreateTrunkAborted(trunkResult, trunkContext) {
      console.error(`${trunkContext.action} aborted`, trunkResult);
      this.error.createTrunk = this.$t("error.generic_error");
      this.loading.createTrunk = false;
    },
    setCreateTrunkCompleted() {
      this.loading.createTrunk = false;
      this.clearErrors();
      this.$emit("hide");
      this.$emit("reloadtrunks");
    },
    onModalHidden() {
      this.clearErrors();
      this.clearFields();
      this.$emit("hide");
    },
  },
};
</script>
<style scoped lang="scss">
@import "../styles/carbon-utils";
.mg-bottom {
  margin-bottom: 3rem !important;
}
.mg-left {
  margin-left: 1rem !important;
}
.max-dropdown-width {
  max-width: 38rem;
}
</style>
