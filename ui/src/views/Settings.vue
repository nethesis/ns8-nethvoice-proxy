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
    <cv-row>
      <cv-column>
        <cv-tile light>
          <cv-form @submit.prevent="configureModule">
            <cv-text-input
              :label="$t('settings.fqdn')"
              v-model="fqdn"
              :placeholder="$t('settings.fqdn')"
              :disabled="loading.getConfiguration || loading.configureModule"
              :invalid-message="error.fqdn"
              :helperText="$t('settings.fqdn_helper')"
              ref="fqdn"
              @input="onFqdnChange"
            ></cv-text-input>
            <NsComboBox
              :title="$t('settings.interfaces')"
              :options="interfacesList"
              :auto-highlight="true"
              :label="$t('settings.interfaces_placeholder')"
              :disabled="loading.getConfiguration || loading.configureModule"
              :invalid-message="error.interfaces"
              :acceptUserInput="false"
              v-model="interfaces"
              ref="interfaces"
              @change="onInterfaceChange"
            />
            <template>
              <div class="input-container">
                <div class="label-and-loading">
                  <label class="input-label">{{
                    $t("settings.address")
                  }}</label>
                  <cv-loading
                    v-if="loading.pathLoading"
                    small
                    class="loading-icon"
                  />
                </div>
                <cv-text-input
                  v-model="address"
                  :placeholder="ipAddressPersonal || $t('settings.address')"
                  :disabled="
                    loading.getConfiguration || loading.configureModule
                  "
                  :invalid-message="error.address"
                  :helperText="$t('settings.address_helper')"
                  ref="address"
                  @input="onInterfaceChange"
                />
              </div>
            </template>
            <cv-row v-if="error.configureModule">
              <cv-column>
                <NsInlineNotification
                  kind="error"
                  :title="$t('action.configure-module')"
                  :description="error.configureModule"
                  :showCloseButton="false"
                />
              </cv-column>
            </cv-row>
            <NsInlineNotification
              v-if="warningVisible"
              kind="warning"
              :title="$t('warning.warning_title_message')"
              :description="$t('warning.different_ip_message')"
              :showCloseButton="false"
            />
            <NsButton
              kind="primary"
              :icon="Save20"
              :loading="loading.configureModule"
              :disabled="loading.getConfiguration || loading.configureModule"
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
      fqdn: "",
      address: "",
      ipAddressPersonal: "",
      public_address: "",
      interfaces: "",
      warningVisible: false,
      loading: {
        getConfiguration: false,
        configureModule: false,
        interfaces: false,
        pathLoading: false,
      },
      interfacesList: [],
      error: {
        getConfiguration: "",
        configureModule: "",
        fqdn: "",
        address: "",
        ipAddressPersonal: "",
        public_address: "",
        interfaces: "",
      },
    };
  },
  computed: {
    ...mapState(["instanceName", "core", "appName"]),
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
    this.getUserInterfaces();
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
      this.loading.getConfiguration = false;
      const config = taskResult.output;
      // set configuration fields
      this.fqdn = config.fqdn;
      this.interfaces = config.addresses.address;
      this.loading.pathLoading = true;

      fetch(`https://dns.google/resolve?name=${this.fqdn}`)
        .then((response) => response.json())
        .then((data) => {
          if (data.Answer && data.Answer.length > 0) {
            for (let record of data.Answer) {
              if (record.type === 1) {
                const publicIP = record.data;
                this.ipAddressPersonal = publicIP;
                break;
              }
            }
            this.address =
              config.addresses.public_address || this.ipAddressPersonal;
          } else {
            this.ipAddressPersonal = null;
            this.address =
              config.addresses.public_address || this.ipAddressPersonal;
          }
        })
        .catch((error) => {
          console.error("Error", error);
        })
        .finally(() => {
          this.loading.pathLoading = false;
        });

      if (this.interfaces !== this.address) {
        this.warningVisible = true;
      }
      // focus first configuration field
      this.focusElement("address");
    },
    validateConfigureModule() {
      this.clearErrors(this);
      let isValidationOk = true;

      if (!this.interfaces) {
        this.error.interfaces = this.$t("common.required");
        isValidationOk = false;
      }
      // validate configuration fields
      if (!this.fqdn) {
        // field cannot be empty
        this.error.fqdn = this.$t("common.required");

        if (isValidationOk) {
          this.focusElement("fqdn");
          isValidationOk = false;
        }
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
        this.loading.pathLoading = true;
        this.fqdnTimeout = setTimeout(() => {
          fetch(`https://dns.google/resolve?name=${this.fqdn}`)
            .then((response) => response.json())
            .then((data) => {
              if (data.Answer && data.Answer.length > 0) {
                for (let record of data.Answer) {
                  if (record.type === 1) {
                    const publicIP = record.data;
                    this.ipAddressPersonal = publicIP;
                    break;
                  }
                }
                if (
                  this.ipAddressPersonal !== null &&
                  (this.address === undefined ||
                    this.address === "" ||
                    this.address === null)
                ) {
                  this.address = this.ipAddressPersonal;
                }
              } else {
                this.ipAddressPersonal = null;
              }
            })
            .catch((error) => {
              console.error("Error", error);
            })
            .finally(() => {
              this.loading.pathLoading = false;
            });
        }, 1000);
      } else {
        this.loading.pathLoading = false;
      }
    },
    async getUserInterfaces() {
      this.loading.userInterfaces = true;

      const taskAction = "get-available-interfaces";
      const eventId = this.getUuid();

      // register to task error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.getUserInterfacesAborted
      );

      // register to task completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.getUserInterfacesCompleted
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
        this.loading.userInterfaces = false;
        return;
      }
    },
    getUserInterfacesCompleted(taskContext, taskResult) {
      this.interfacesList = [];
      for (const test of taskResult.output.data) {
        const interfacesAddress = test.addresses[0].address;
        const label = `${test.name} - ${interfacesAddress}`;

        this.interfacesList.push({
          name: test.name,
          label: label,
          value: interfacesAddress,
        });
      }
      this.loading.userInterfaces = false;
      this.getConfiguration();
    },
    getUserInterfacesAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.getConfiguration = this.$t("error.generic_error");
      this.loading.userInterfaces = false;
      this.getConfiguration();
    },
    configureModuleValidationFailed(validationErrors) {
      this.loading.configureModule = false;

      for (const validationError of validationErrors) {
        let field = this.getValidationErrorField(validationError);

        if (field !== "(root)") {
          // set i18n error message
          this.error[field] = this.$t("settings." + validationError.error);
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
          address: this.interfaces,
        },
      };

      // check if public_address exists and is different from local ip address
      if (this.address && this.address !== this.interfaces) {
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
    onInterfaceChange() {
      if (this.interfaces !== this.address) {
        this.warningVisible = true;
      } else {
        this.warningVisible = false;
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
