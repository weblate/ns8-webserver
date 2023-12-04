<template>
  <div class="bx--grid bx--grid--full-width">
    <div class="bx--row">
      <div class="bx--col-lg-16 page-title">
        <h2>{{ $t("settings.title") }}</h2>
      </div>
    </div>
    <div v-if="error.getConfiguration" class="bx--row">
      <div class="bx--col">
        <NsInlineNotification
          kind="error"
          :title="$t('action.get-configuration')"
          :description="error.getConfiguration"
          :showCloseButton="false"
        />
      </div>
    </div>
    <div class="bx--row">
      <div class="bx--col-lg-16">
        <cv-tile :light="true">
          <cv-form @submit.prevent="configureModule">
            <template>
              <NsTextInput
                :label="$t('settings.sftpgo_path')"
                :placeholder="$t('settings.for_example')+' /sftpgo'"
                v-model.trim="path"
                class="mg-bottom"
                :invalid-message="$t(error.path)"
                :disabled="loading.getConfiguration || loading.configureModule"
                ref="path"
                tooltipAlignment="center"
                tooltipDirection="right"
              >
                <template slot="tooltip">
                  <div
                    v-html="
                      $t('settings.sftpgo_path_tips')
                    "
                  ></div>
                </template>
              </NsTextInput>
              <NsTextInput
                :label="$t('settings.sftp_tcp_port')"
                placeholder="3092"
                v-model.trim="sftp_tcp_port"
                class="mg-bottom"
                :invalid-message="$t(error.sftp_tcp_port)"
                :disabled="loading.getConfiguration || loading.configureModule"
                ref="sftp_tcp_port"
                tooltipAlignment="center"
                tooltipDirection="right"
              >
                <template slot="tooltip">
                  <div
                    v-html="
                      $t('settings.sftp_tcp_port_tips')
                    "
                  ></div>
                </template>
              </NsTextInput>
              <NsToggle
                :label="$t('settings.sftpgo_restrict_port_access')"
                value="sftpgo_switch"
                :form-item="true"
                v-model="isSftpgoPortEnabled"
                :disabled="loading.getConfiguration || loading.configureModule"
                ref="sftpgo_switch"
                class="mg-bottom"
              >
                <template slot="tooltip">
                  <span
                    v-html="$t('settings.sftpgo_explanation_tooltips')"
                  ></span>
                </template>
                <template slot="text-left">{{ $t("common.disabled") }}</template>
                <template slot="text-right">{{ $t("common.enabled") }}</template>
              </NsToggle>
              <cv-toggle
                value="httpToHttps"
                :label="$t('settings.http_to_https')"
                v-model="isHttpToHttpsEnabled"
                :disabled="loading.getConfiguration || loading.configureModule"
                class="mg-bottom"
              >
                <template slot="text-left">{{
                  $t("settings.disabled")
                }}</template>
                <template slot="text-right">{{
                  $t("settings.enabled")
                }}</template>
              </cv-toggle>
            </template>
            <div v-if="error.configureModule" class="bx--row">
              <div class="bx--col">
                <NsInlineNotification
                  kind="error"
                  :title="$t('action.configure-module')"
                  :description="error.configureModule"
                  :showCloseButton="false"
                />
              </div>
            </div>
            <NsButton
              kind="primary"
              :icon="Save20"
              :loading="loading.configureModule"
              :disabled="loading.getConfiguration || loading.configureModule"
              >{{ $t("settings.save") }}</NsButton
            >
          </cv-form>
        </cv-tile>
      </div>
    </div>
  </div>
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
      hostname: location.hostname,
      urlCheckInterval: null,
      path: "",
      sftp_tcp_port: "",
      isHttpToHttpsEnabled: false,
      isSftpgoPortEnabled: false,
      loading: {
        getConfiguration: false,
        configureModule: false,
      },
      error: {
        getConfiguration: "",
        configureModule: "",
        path: "",
        lets_encrypt: "",
        http2https: "",
      },
    };
  },
  computed: {
    ...mapState(["instanceName", "core", "appName"]),
  },
  created() {
    this.getConfiguration();
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
  methods: {
    async getConfiguration() {
      this.loading.getConfiguration = true;
      this.error.getConfiguration = "";
      const taskAction = "get-configuration";

      // register to task error
      this.core.$root.$off(taskAction + "-aborted");
      this.core.$root.$once(
        taskAction + "-aborted",
        this.getConfigurationAborted
      );

      // register to task completion
      this.core.$root.$off(taskAction + "-completed");
      this.core.$root.$once(
        taskAction + "-completed",
        this.getConfigurationCompleted
      );

      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          extra: {
            title: this.$t("action." + taskAction),
            isNotificationHidden: true,
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
      this.error.getConfiguration = this.core.$t("error.generic_error");
      this.loading.getConfiguration = false;
    },
    getConfigurationCompleted(taskContext, taskResult) {
      const config = taskResult.output;
      this.path = config.path;
      this.sftp_tcp_port = config.sftp_tcp_port;
      this.isHttpToHttpsEnabled = config.http2https;
      this.isSftpgoPortEnabled = config.sftpgo_service
      this.loading.getConfiguration = false;
      this.focusElement("path");
    },
    validateConfigureModule() {
      this.clearErrors(this);
      let isValidationOk = true;
      if (!this.path) {
        this.error.path = "common.required";
        if (isValidationOk) {
          this.focusElement("path");
        }
        isValidationOk = false;
      }
      return isValidationOk;
    },
    configureModuleValidationFailed(validationErrors) {
      this.loading.configureModule = false;
      let focusAlreadySet = false;

      for (const validationError of validationErrors) {
        const param = validationError.parameter;
        // set i18n error message
        this.error[param] = "settings." + validationError.error;

        if (!focusAlreadySet) {
          this.focusElement(param);
          focusAlreadySet = true;
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

      // register to task error
      this.core.$root.$off(taskAction + "-aborted");
      this.core.$root.$once(
        taskAction + "-aborted",
        this.configureModuleAborted
      );

      // register to task validation
      this.core.$root.$off(taskAction + "-validation-failed");
      this.core.$root.$once(
        taskAction + "-validation-failed",
        this.configureModuleValidationFailed
      );

      // register to task completion
      this.core.$root.$off(taskAction + "-completed");
      this.core.$root.$once(
        taskAction + "-completed",
        this.configureModuleCompleted
      );

      const res = await to(
        this.createModuleTaskForApp(this.instanceName, {
          action: taskAction,
          data: {
            path: this.path,
            sftp_tcp_port: parseInt(this.sftp_tcp_port),
            http2https: this.isHttpToHttpsEnabled,
            sftpgo_service: this.isSftpgoPortEnabled,
          },
          extra: {
            title: this.$t("settings.instance_configuration", {
              instance: this.instanceName,
            }),
            description: this.$t("settings.configuring"),
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
      this.error.configureModule = this.core.$t("error.generic_error");
      this.loading.configureModule = false;
    },
    configureModuleCompleted() {
      this.loading.configureModule = false;

      // reload configuration
      this.getConfiguration();
    },
  },
};
</script>

<style scoped lang="scss">
@import "../styles/carbon-utils";
.mg-bottom {
  margin-bottom: $spacing-06;
}
.mg-left {
  margin-left: $spacing-05;
}
</style>