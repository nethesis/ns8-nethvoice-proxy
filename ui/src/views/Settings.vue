<!--
  Copyright (C) 2024 Nethesis S.r.l.
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <cv-grid fullWidth>
    <cv-row>
      <cv-column class="page-title">
        <h2>{{ $t("settings.title") }}</h2>
      </cv-column>
    </cv-row>
    <cv-row v-if="error.getConfiguration">
      <cv-column>
        <NsInlineNotification
          kind="error"
          :title="$t('action.get-configuration')"
          :description="error.getConfiguration"
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row v-if="error.getStatus">
      <cv-column>
        <NsInlineNotification
          kind="error"
          :title="$t('action.get-status')"
          :description="error.getStatus"
          :showCloseButton="false"
        />
      </cv-column>
    </cv-row>
    <cv-row>
      <cv-column>
        <cv-tile light>
          <cv-skeleton-text
            v-show="loading.getConfiguration"
            :paragraph="true"
            heading
            :line-count="10"
          ></cv-skeleton-text>
          <cv-form
            v-show="!loading.getConfiguration"
            @submit.prevent="configureModule"
          >
            <NsTextInput
              :label="$t('settings.fqdn')"
              v-model="fqdn"
              :placeholder="$t('settings.fqdn')"
              :disabled="loading.configureModule"
              :invalid-message="error.fqdn"
              :helperText="$t('settings.fqdn_helper')"
              ref="fqdn"
              @input="onFqdnChange"
            ></NsTextInput>
            <!-- let's encrypt toggle -->
            <NsToggle
              value="letsEncrypt"
              :label="core.$t('apps_lets_encrypt.request_https_certificate')"
              v-model="isLetsEncryptEnabled"
              :disabled="loading.configureModule"
            >
              <template #tooltip>
                <div class="mg-bottom-sm">
                  {{ core.$t("apps_lets_encrypt.lets_encrypt_tips") }}
                </div>
                <div class="mg-bottom-sm">
                  <cv-link @click="goToCertificates">
                    {{ core.$t("apps_lets_encrypt.go_to_tls_certificates") }}
                  </cv-link>
                </div>
              </template>
              <template slot="text-left">{{
                core.$t("common.disabled")
              }}</template>
              <template slot="text-right">{{
                core.$t("common.enabled")
              }}</template>
            </NsToggle>
            <!-- disabling let's encrypt warning -->
            <NsInlineNotification
              v-if="
                isLetsEncryptCurrentlyEnabled && !isLetsEncryptEnabled && status
              "
              kind="warning"
              :title="
                core.$t('apps_lets_encrypt.lets_encrypt_disabled_warning')
              "
              :description="
                core.$t(
                  'apps_lets_encrypt.lets_encrypt_disabled_warning_description',
                  {
                    node: status.node_ui_name
                      ? status.node_ui_name
                      : status.node,
                  }
                )
              "
              :showCloseButton="false"
            />
            <NsComboBox
              :title="$t('settings.interface')"
              :options="interfaces"
              :auto-highlight="true"
              :label="
                loading.getAvailableInterfaces
                  ? $t('common.loading')
                  : $t('settings.interface_placeholder')
              "
              :disabled="
                loading.configureModule || loading.getAvailableInterfaces
              "
              :invalid-message="error.iface"
              :acceptUserInput="false"
              v-model="iface"
              ref="iface"
            />
            <!-- public address -->
            <div class="flex flex-col">
              <div class="flex">
                <div class="bx--label mb-0">
                  {{
                    `${$t("settings.address")} (${core.$t("common.optional")})`
                  }}
                  <cv-interactive-tooltip
                    alignment="start"
                    direction="bottom"
                    class="info relative top-0.5"
                  >
                    <template slot="content">
                      {{ $t("settings.address_tooltip") }}
                    </template>
                  </cv-interactive-tooltip>
                </div>
                <cv-loading
                  v-if="loading.resolveFqdn"
                  small
                  class="mg-left-sm"
                />
              </div>
              <cv-text-input
                v-model="address"
                :disabled="loading.configureModule"
                :invalid-message="error.public_address"
                :helperText="$t('settings.address_helper')"
                ref="public_address"
              />
            </div>
            <NsInlineNotification
              v-if="addressAndInterfaceDontMatch"
              kind="warning"
              :title="$t('settings.address_and_iface_dont_match')"
              :description="$t('settings.address_and_iface_dont_match_message')"
              :showCloseButton="false"
            />
            <NsInlineNotification
              v-if="validationErrorDetails.length"
              kind="error"
              :title="core.$t('apps_lets_encrypt.cannot_obtain_certificate')"
              :showCloseButton="false"
            >
              <template #description>
                <div class="flex flex-col gap-2">
                  <div
                    v-for="(detail, index) in validationErrorDetails"
                    :key="index"
                  >
                    {{ detail }}
                  </div>
                </div>
              </template>
            </NsInlineNotification>
            <NsInlineNotification
              v-if="error.configureModule"
              kind="error"
              :title="$t('action.configure-module')"
              :description="error.configureModule"
              :showCloseButton="false"
            />
            <NsButton
              kind="primary"
              :icon="Save20"
              :loading="loading.configureModule"
              :disabled="loading.configureModule"
              >{{ $t("settings.save") }}</NsButton
            >
          </cv-form>
        </cv-tile>
      </cv-column>
    </cv-row>
  </cv-grid>
</template>

<script>
import to from "await-to-js";
import { mapState } from "vuex";
import {
  QueryParamService,
  UtilService,
  TaskService,
  IconService,
  PageTitleService,
} from "@nethserver/ns8-ui-lib";

export default {
  name: "Settings",
  mixins: [
    TaskService,
    IconService,
    UtilService,
    QueryParamService,
    PageTitleService,
  ],
  pageTitle() {
    return this.$t("settings.title") + " - " + this.appName;
  },
  data() {
    return {
      q: {
        page: "settings",
      },
      urlCheckInterval: null,
      config: null,
      fqdn: "",
      address: "",
      resolvedIp: "",
      ipAddressPersonal: "",
      public_address: "",
      iface: "",
      fqdnTimeout: 0,
      isLetsEncryptEnabled: false,
      isLetsEncryptCurrentlyEnabled: false,
      validationErrorDetails: [],
      status: null,
      loading: {
        getConfiguration: false,
        configureModule: false,
        getAvailableInterfaces: false,
        resolveFqdn: false,
        getStatus: false,
      },
      interfaces: [],
      error: {
        getConfiguration: "",
        configureModule: "",
        getAvailableInterfaces: "",
        fqdn: "",
        address: "",
        ipAddressPersonal: "",
        public_address: "",
        iface: "",
        getStatus: "",
      },
    };
  },
  computed: {
    ...mapState(["instanceName", "core", "appName"]),
    addressAndInterfaceDontMatch() {
      return this.address && this.iface && this.address !== this.iface;
    },
  },
  watch: {
    interfaces() {
      this.updateIfaceValue();
    },
    config() {
      this.updateIfaceValue();
    },
  },
  beforeRouteEnter(to, from, next) {
    next((vm) => {
      vm.watchQueryData(vm);
      vm.urlCheckInterval = vm.initUrlBindingForApp(vm, vm.q.page);
    });
  },
  beforeRouteLeave(to, from, next) {
    clearInterval(this.urlCheckInterval);
    next();
  },
  created() {
    this.getConfiguration();
    this.getAvailableInterfaces();
    this.getStatus();
  },
  methods: {
    async getConfiguration() {
      this.loading.getConfiguration = true;
      this.error.getConfiguration = "";
      const taskAction = "get-configuration";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.getConfigurationAborted
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.getConfigurationCompleted
      );

      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          extra: {
            title: this.$t("action." + taskAction),
            isNotificationHidden: true,
            eventId,
          },
        })
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.getConfiguration = this.getErrorMessage(err);
        this.loading.getConfiguration = false;
        return;
      }
    },
    getConfigurationAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.getConfiguration = this.$t("error.generic_error");
      this.loading.getConfiguration = false;
    },
    getConfigurationCompleted(taskContext, taskResult) {
      const config = taskResult.output;
      this.config = config;
      this.fqdn = config.fqdn;
      this.isLetsEncryptEnabled = config.lets_encrypt;
      this.isLetsEncryptCurrentlyEnabled = config.lets_encrypt;

      // this.iface is set on get-available-interfaces completion

      if (config.addresses.public_address) {
        this.address = config.addresses.public_address;
      } else {
        this.resolveFqdn();
      }
      this.loading.getConfiguration = false;

      // focus first configuration field
      this.focusElement("fqdn");
    },
    validateConfigureModule() {
      this.clearErrors(this);
      this.validationErrorDetails = [];
      let isValidationOk = true;

      if (!this.fqdn) {
        this.error.fqdn = this.$t("common.required");

        if (isValidationOk) {
          this.focusElement("fqdn");
          isValidationOk = false;
        }
      } else if (this.fqdn.endsWith(".invalid")) {
        this.error.fqdn = this.$t("error.invalid_fqdn");

        if (isValidationOk) {
          this.focusElement("fqdn");
          isValidationOk = false;
        }
      }

      if (!this.iface) {
        this.error.iface = this.$t("common.required");
        isValidationOk = false;
      }
      return isValidationOk;
    },
    getValidationErrorField(validationError) {
      // error field could be "parameters.fieldName", let's take "fieldName" only
      const fieldTokens = validationError.field.split(".");
      return fieldTokens[fieldTokens.length - 1];
    },
    onFqdnChange() {
      if (this.fqdnTimeout) {
        clearTimeout(this.fqdnTimeout);
      }

      if (this.fqdn.trim() !== "") {
        this.loading.resolveFqdn = true;

        this.fqdnTimeout = setTimeout(() => {
          this.resolveFqdn();
        }, 1000);
      } else {
        this.loading.resolveFqdn = false;
      }
    },
    resolveFqdn() {
      fetch(`https://dns.google/resolve?name=${this.fqdn}`)
        .then((response) => response.json())
        .then((data) => {
          if (data.Answer && data.Answer.length > 0) {
            for (let record of data.Answer) {
              if (record.type === 1) {
                this.resolvedIp = record.data;
                break;
              }
            }
            this.address = this.resolvedIp;
          } else {
            this.resolvedIp = "";
          }
        })
        .catch((error) => {
          console.error("Error resolving fqdn", error);
        })
        .finally(() => {
          this.loading.resolveFqdn = false;
        });
    },
    async getAvailableInterfaces() {
      this.loading.getAvailableInterfaces = true;

      const taskAction = "get-available-interfaces";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.getAvailableInterfacesAborted
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.getAvailableInterfacesCompleted
      );

      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          data: {
            excluded_interfaces: ["lo", "wg0"],
            excluded_families: ["inet6"],
          },
          extra: {
            title: this.$t("action." + taskAction),
            isNotificationHidden: true,
            eventId,
          },
        })
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.getConfiguration = this.getErrorMessage(err);
        this.loading.getAvailableInterfaces = false;
        return;
      }
    },
    getAvailableInterfacesCompleted(taskContext, taskResult) {
      const interfaces = [];

      for (const iface of taskResult.output.data) {
        const interfacesAddress = iface.addresses[0].address;
        const label = `${iface.name} - ${interfacesAddress}`;

        interfaces.push({
          name: iface.name,
          label: label,
          value: interfacesAddress,
        });
      }
      this.interfaces = interfaces;
      this.loading.getAvailableInterfaces = false;
    },
    getAvailableInterfacesAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.getConfiguration = this.$t("error.generic_error");
      this.loading.getAvailableInterfaces = false;
      this.getConfiguration();
    },
    configureModuleValidationFailed(validationErrors) {
      this.loading.configureModule = false;

      for (const validationError of validationErrors) {
        if (validationError.details) {
          // show inline error notification with details
          this.validationErrorDetails = validationError.details
            .split("\n")
            .filter((detail) => detail.trim() !== "");
        } else {
          let field = this.getValidationErrorField(validationError);

          if (field !== "(root)") {
            // set i18n error message
            this.error[field] = this.$t("settings." + validationError.error);
          }
        }
      }
    },
    async configureModule() {
      const isValidationOk = this.validateConfigureModule();
      if (!isValidationOk) {
        return;
      }

      this.loading.configureModule = true;
      const taskAction = "configure-module";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.configureModuleAborted
      );

      // register to task validation
      this.core.$root.$once(
        `${taskAction}-validation-failed-${eventId}`,
        this.configureModuleValidationFailed
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.configureModuleCompleted
      );

      // build data payload
      let dataPayload = {
        fqdn: this.fqdn,
        addresses: {
          address: this.iface,
        },
        lets_encrypt: this.isLetsEncryptEnabled,
      };

      // check if public_address exists and is different from local ip address
      if (this.address && this.address !== this.iface) {
        dataPayload.addresses.public_address = this.address;
      }

      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          data: dataPayload,
          extra: {
            title: this.$t("settings.configure_instance", {
              instance: this.instanceName,
            }),
            description: this.$t("common.processing"),
            eventId,
          },
        })
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.configureModule = this.getErrorMessage(err);
        this.loading.configureModule = false;
        return;
      }
    },
    configureModuleAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.configureModule = this.$t("error.generic_error");
      this.loading.configureModule = false;
    },
    configureModuleCompleted() {
      this.loading.configureModule = false;

      // reload configuration
      this.getConfiguration();
    },
    async getStatus() {
      this.loading.getStatus = true;
      this.error.getStatus = "";
      const taskAction = "get-status";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.getStatusAborted
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.getStatusCompleted
      );

      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          extra: {
            title: this.$t("action." + taskAction),
            isNotificationHidden: true,
            eventId,
          },
        })
      );
      const err = res[0];

      if (err) {
        console.error(`error creating task ${taskAction}`, err);
        this.error.getStatus = this.getErrorMessage(err);
        this.loading.getStatus = false;
        return;
      }
    },
    getStatusAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.getStatus = this.$t("error.generic_error");
      this.loading.getStatus = false;
    },
    getStatusCompleted(taskContext, taskResult) {
      this.status = taskResult.output;
      this.loading.getStatus = false;
    },
    goToCertificates() {
      this.core.$router.push("/settings/tls-certificates");
    },
    updateIfaceValue() {
      if (
        this.interfaces &&
        this.interfaces.length &&
        this.config &&
        this.config.addresses.address &&
        this.config.addresses.address !== "127.0.0.1"
      ) {
        this.$nextTick(() => {
          this.iface = this.config.addresses.address;
        });
      }
    },
  },
};
</script>

<style scoped lang="scss">
@import "../styles/carbon-utils";

.input-label {
  font-size: 12px;
  color: #525252;
}
.label-and-loading {
  display: flex;
  align-items: center;
}

.loading-icon {
  margin-left: 10px;
}
</style>
