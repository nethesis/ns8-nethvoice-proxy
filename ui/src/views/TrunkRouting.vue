<!--
  Copyright (C) 2025 Nethesis S.r.l.
  SPDX-License-Identifier: GPL-3.0-or-later
-->
<template>
  <div>
    <cv-grid fullWidth>
      <cv-row>
        <cv-column class="page-title">
          <h2>
            {{ $t("trunks.title") }}
          </h2>
        </cv-column>
      </cv-row>
      <cv-row>
        <cv-column>
          <NsInlineNotification
            kind="warning"
            :title="core.$t('common.use_landscape_mode')"
            :description="core.$t('common.use_landscape_mode_description')"
            class="landscape-warning"
          />
        </cv-column>
      </cv-row>
      <cv-row v-if="error.listProviders">
        <cv-column>
          <NsInlineNotification
            kind="error"
            :title="$t('error.error_loading_providers')"
            :description="error.listProviders"
            :showCloseButton="false"
          />
        </cv-column>
      </cv-row>
      <cv-row class="toolbar">
        <cv-column>
          <div>
            <NsButton
              v-if="trunks.length"
              kind="primary"
              class="page-toolbar-item"
              :icon="Add20"
              @click="toggleCreateTrunk"
              :disabled="
                loading.listTrunks ||
                loading.setDeleteTrunk ||
                !sip_providers.length
              "
              >{{ $t("trunks.add_rule") }}
            </NsButton>
          </div>
        </cv-column>
      </cv-row>
      <cv-row v-if="!sip_providers.length && trunks.length && !(loading.listTrunks || loading.setDeleteTrunk)">
        <cv-column>
          <NsInlineNotification
            kind="warning"
            :title="$t('trunks.providers_are_missing')"
            :description="$t('trunks.providers_are_missing_description')"
            :showCloseButton="false"
            @click="goToSoftwareCenter()"
            :actionLabel="$t('trunks.go_to_software_center')"
          />
        </cv-column>
      </cv-row>
      <cv-row>
        <cv-column>
          <cv-tile light>
            <NsDataTable
              :allRows="trunks"
              :columns="i18nTableColumns"
              :rawColumns="tableColumns"
              :sortable="true"
              :pageSizes="[10, 25, 50, 100]"
              :overflow-menu="true"
              :isSearchable="check_trunks"
              :searchPlaceholder="$t('trunks.search_trunks')"
              :searchClearLabel="core.$t('common.clear_search')"
              :noSearchResultsLabel="core.$t('common.no_search_results')"
              :noSearchResultsDescription="
                core.$t('common.no_search_results_description')
              "
              :isLoading="loading.listTrunks || loading.setDeleteTrunk"
              :skeletonRows="5"
              :isErrorShown="!!error.listTrunks"
              :errorTitle="$t('action.Trunks_list_error')"
              :errorDescription="error.listTrunks"
              :itemsPerPageLabel="core.$t('pagination.items_per_page')"
              :rangeOfTotalItemsLabel="
                core.$t('pagination.range_of_total_items')
              "
              :ofTotalPagesLabel="core.$t('pagination.of_total_pages')"
              :backwardText="core.$t('pagination.previous_page')"
              :forwardText="core.$t('pagination.next_page')"
              :pageNumberLabel="core.$t('pagination.page_number')"
              @updatePage="tablePage = $event"
            >
              <template slot="empty-state">
                <template v-if="!trunks.length && sip_providers.length">
                  <NsEmptyState :title="$t('trunks.no_trunks')">
                    <template #pictogram>
                      <ExclamationMarkPictogram />
                    </template>
                    <template #description>
                      <div>
                        {{ $t("trunks.no_trunks_description") }}
                      </div>
                      <NsButton
                        kind="primary"
                        class="empty-state-button"
                        :icon="Add20"
                        @click="toggleCreateTrunk"
                        :disabled="loading.listTrunks || loading.setDeleteTrunk"
                        >{{ $t("trunks.add_rule") }}
                      </NsButton>
                    </template>
                  </NsEmptyState>
                </template>
                <template
                  v-else-if="!sip_providers.length && !error.listProviders"
                >
                  <NsEmptyState :title="$t('trunks.providers_are_missing')">
                    <template #pictogram>
                      <ExclamationMarkPictogram />
                    </template>
                    <template #description>
                      <div>
                        {{ $t("trunks.providers_are_missing_description") }}
                      </div>
                      <NsButton
                        kind="primary"
                        class="empty-state-button"
                        :icon="ArrowRight20"
                        @click="goToSoftwareCenter()"
                        :disabled="loading.listTrunks || loading.setDeleteTrunk"
                        >{{ $t("trunks.go_to_software_center") }}
                      </NsButton>
                    </template>
                  </NsEmptyState>
                </template>
              </template>
              <template slot="data">
                <cv-data-table-row
                  v-for="(row, rowIndex) in tablePage"
                  :key="`${rowIndex}`"
                  :value="`${rowIndex}`"
                >
                  <cv-data-table-cell>
                    {{ row.rule }}
                  </cv-data-table-cell>
                  <cv-data-table-cell>
                    {{ row.instances }}
                  </cv-data-table-cell>
                  <cv-data-table-cell class="table-overflow-menu-cell">
                    <cv-overflow-menu
                      flip-menu
                      class="table-overflow-menu"
                      :data-test-id="row.rule + '-menu'"
                    >
                      <cv-overflow-menu-item
                        @click="toggleEditTrunk(row)"
                        :data-test-id="row.rule + '-edit-rule'"
                        :disabled="!sip_providers.length"
                      >
                        <NsMenuItem :icon="Edit20" :label="$t('trunks.edit')" />
                      </cv-overflow-menu-item>
                      <cv-overflow-menu-item
                        danger
                        @click="toggleDeleteTrunk(row)"
                        :data-test-id="row.rule + '-delete-rule'"
                      >
                        <NsMenuItem
                          :icon="TrashCan20"
                          :label="$t('trunks.delete')"
                        />
                      </cv-overflow-menu-item>
                    </cv-overflow-menu>
                  </cv-data-table-cell>
                </cv-data-table-row>
              </template>
            </NsDataTable>
          </cv-tile>
        </cv-column>
      </cv-row>
    </cv-grid>
    <ConfirmDeleteTrunk
      :isShown="isShownConfirmDeleteTrunk"
      :trunk="currentTrunk"
      :core="core"
      @hide="hideConfirmDeleteTrunk"
      @confirm="setDeleteTrunk(false)"
    />
    <CreateOrEditTrunk
      :isShown="isShownCreateOrEditTrunk"
      :trunk="currentTrunk"
      :isEdit="isEdit"
      :sip_providers="sip_providers"
      :rule_names="rule_names"
      @hide="hideCreateOrEditTrunk"
      @reloadtrunks="listTrunks"
    />
  </div>
</template>

<script>
import { mapState } from "vuex";
import {
  QueryParamService,
  UtilService,
  IconService,
  TaskService,
  DateTimeService,
  PageTitleService,
} from "@nethserver/ns8-ui-lib";
import to from "await-to-js";
import ConfirmDeleteTrunk from "@/components/ConfirmDeleteTrunk";
import CreateOrEditTrunk from "@/components/CreateOrEditTrunk";

export default {
  name: "TrunkRouting",
  components: {
    ConfirmDeleteTrunk,
    CreateOrEditTrunk,
  },
  mixins: [
    QueryParamService,
    UtilService,
    IconService,
    TaskService,
    DateTimeService,
    PageTitleService,
  ],
  pageTitle() {
    return this.$t("trunks.title") + " - " + this.appName;
  },
  data() {
    return {
      q: {
        page: "trunkrouting",
      },
      urlCheckInterval: null,
      tablePage: [],
      tableColumns: ["rule", "instances"],
      trunks: [], // list of existing trunks
      sip_providers: [], // list of available sip providers for destination
      rule_names: [], // list of existing rule names for unique check
      isEdit: false,
      check_trunks: false,
      isShownConfirmDeleteTrunk: false,
      isShownCreateOrEditTrunk: false,
      isShowListInformations: false,
      currentTrunk: {
        rule: "",
        destination: { uri: "", description: "" },
      },
      loading: {
        listTrunks: false,
        setDeleteTrunk: false,
      },
      error: {
        listTrunks: "",
        setDeleteTrunk: "",
        listProviders: "",
      },
    };
  },
  computed: {
    ...mapState(["instanceName", "core", "appName"]),
    i18nTableColumns() {
      return this.tableColumns.map((column) => {
        return this.$t("trunks.col_" + column);
      });
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
    this.$root.$on("reloadtrunks", this.listTrunks);
    this.listTrunks();
  },
  beforeDestroy() {
    // remove event listener
    this.$root.$off("reloadtrunks");
  },
  methods: {
    async listTrunks() {
      this.trunks = [];
      this.rule_names = []; // reset rule names array for unique check
      const taskAction = "list-trunks";
      const eventId = this.getUuid();
      this.loading.listTrunks = true;
      // register to trunk events
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.listTrunksAborted
      );
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.listTrunksCompleted
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
        console.error(`error creating trunk ${taskAction}`, err);
        const errMessage = this.getErrorMessage(err);
        this.error.listTrunks = errMessage;
        this.loading.listTrunks = false;
      }
    },
    listTrunksAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.listTrunks = this.$t("error.generic_error");
      this.loading.listTrunks = false;
    },
    listTrunksCompleted(taskContext, taskResult) {
      this.trunks = taskResult.output;
      // parse the trunks and set to instances the description, hack for the search function
      this.trunks.forEach((trunk) => {
        trunk.instances = trunk.destination.description;
      });
      // list all trunks rule names, used to check if a trunk already exists
      this.rule_names = this.trunks.map((trunk) => trunk.rule);
      // display the search bar only if we have trunks
      this.check_trunks = this.trunks.length ? true : false;
      this.listProviders();
    },
    async listProviders() {
      this.sip_providers = [];
      const taskAction = "list-service-providers";
      const eventId = this.getUuid();
      this.loading.listTrunks = true;
      this.error.listProviders = "";
      // register to trunk events
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.listProvidersAborted
      );
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.listProvidersCompleted
      );
      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          data: {
            service: "sip",
            transport: "udp",
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
        console.error(`error creating trunk ${taskAction}`, err);
        const errMessage = this.getErrorMessage(err);
        this.error.listProviders = errMessage;
        this.loading.listTrunks = false;
      }
    },
    listProvidersAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.listProviders = this.$t("error.generic_error");
      this.loading.listTrunks = false;
    },
    formatSipProviders(providers) {
      return providers
        .map((provider) => {
          // validation of providers with missing fields and display an error
          // we stop if one provider is not valid, nscombobox will not display any entry
          if (!provider.module_id || !provider.node_address || !provider.port) {
            this.error.listProviders = this.$t(
              "error.provider_missing_fields",
              {
                module_id: provider.module_id || "unknown",
              }
            );
            return null;
          }
          return {
            name: provider.module_id,
            label: provider.ui_name
              ? provider.ui_name +
                " (" +
                provider.module_id +
                " - " +
                provider.node_address +
                ")"
              : provider.module_id + " (" + provider.node_address + ")",
            value: provider.ui_name
              ? provider.ui_name +
                " (" +
                provider.module_id +
                ")" +
                "," +
                provider.module_id +
                ",sip:" +
                provider.node_address +
                ":" +
                provider.port
              : provider.module_id +
                ",sip:" +
                provider.node_address +
                ":" +
                provider.port,
          };
        })
        .filter((item) => item !== null);
    },
    listProvidersCompleted(taskContext, taskResult) {
      // Find the node value for the current instance
      const currentInstance = taskResult.output.find(
        (provider) => provider.module_id === this.instanceName
      );
      const currentNode = currentInstance ? currentInstance.node : null;

      // Remove the current instance from the list
      taskResult.output = taskResult.output.filter(
        (provider) => provider.module_id !== this.instanceName
      );

      // Keep only providers with the same node value
      if (currentNode !== null) {
        taskResult.output = taskResult.output.filter(
          (provider) => provider.node === currentNode
        );
      }
      // Format the remaining providers
      this.sip_providers = this.formatSipProviders(taskResult.output);
      this.loading.listTrunks = false;
    },
    toggleEditTrunk(trunk) {
      this.currentTrunk = trunk;
      this.isEdit = true;
      this.showCreateOrEditTrunk();
    },
    toggleCreateTrunk() {
      this.isEdit = false;
      this.currentTrunk = {
        rule: "",
        destination: "",
      };
      this.showCreateOrEditTrunk();
    },
    showCreateOrEditTrunk() {
      this.isShownCreateOrEditTrunk = true;
    },
    hideCreateOrEditTrunk() {
      this.isShownCreateOrEditTrunk = false;
    },
    toggleDeleteTrunk(trunk) {
      this.currentTrunk = trunk;
      this.showConfirmDeleteTrunk();
    },
    showConfirmDeleteTrunk() {
      this.isShownConfirmDeleteTrunk = true;
    },
    hideConfirmDeleteTrunk() {
      this.isShownConfirmDeleteTrunk = false;
    },
    async setDeleteTrunk() {
      this.loading.setDeleteTrunk = true;
      this.error.setDeleteTrunk = "";
      const taskAction = "remove-trunk";
      const eventId = this.getUuid();
      // register to trunk error
      this.core.$root.$once(
        `${taskAction}-aborted-${eventId}`,
        this.setDeleteTrunkAborted
      );
      // register to trunk completion
      this.core.$root.$once(
        `${taskAction}-completed-${eventId}`,
        this.setDeleteTrunkCompleted
      );
      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          data: {
            rule: this.currentTrunk.rule,
          },
          extra: {
            title: this.$t("action.delete-rule"),
            isNotificationHidden: false,
            eventId,
          },
        })
      );
      const err = res[0];

      if (err) {
        console.error(`error creating trunk ${taskAction}`, err);
        this.error.setDeleteTrunk = this.getErrorMessage(err);
        this.loading.setDeleteTrunk = false;
        return;
      }
      this.hideConfirmDeleteTrunk();
    },
    setDeleteTrunkAborted(taskResult, taskContext) {
      console.error(`${taskContext.action} aborted`, taskResult);
      this.error.setDeleteTrunk = this.$t("error.generic_error");
      this.loading.setDeleteTrunk = false;
    },
    setDeleteTrunkCompleted() {
      this.loading.setDeleteTrunk = false;
      this.hideConfirmDeleteTrunk();
      this.listTrunks();
    },
    goToSoftwareCenter() {
      this.core.$router.push("/software-center");
    },
  },
};
</script>

<style scoped lang="scss">
@import "../styles/carbon-utils";
.empty-state-button {
  margin-top: $spacing-07;
  margin-bottom: $spacing-07;
}
</style>
