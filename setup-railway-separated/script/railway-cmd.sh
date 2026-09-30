#!/bin/bash
set -e

if [ -z "$RFP_DOMAIN_NAME" ]; then
    echo "ERROR: RFP_DOMAIN_NAME is not set" >&2
    exit 1
fi

SITE_CONFIG="/home/frappe/frappe-bench/sites/${RFP_DOMAIN_NAME}/site_config.json"

if [ ! -f "$SITE_CONFIG" ]; then
    echo "-> Site config not found, running setup"
    /home/frappe/frappe-bench/railway-setup.sh
fi

echo "-> Installing apps missing from the site"
INSTALLED_APPS=$(su frappe -c "bench --site ${RFP_DOMAIN_NAME} list-apps" | awk 'NF {print $1}')
for APP in $(cat /home/frappe/frappe-bench/sites/apps.txt); do
    if grep -qx "${APP}" <<<"${INSTALLED_APPS}"; then
        continue
    fi
    echo "-> Installing ${APP}"
    su frappe -c "bench --site ${RFP_DOMAIN_NAME} install-app ${APP}"
done

echo "-> Clearing cache"
su frappe -c "bench execute frappe.cache_manager.clear_global_cache"

echo "-> Resolving paths"
BENCH_PATH=$(su frappe -c "which bench")
NODE_PATH=$(su frappe -c "which node")
export BENCH_PATH NODE_PATH

echo "-> Bursting env into config"
envsubst '$RFP_DOMAIN_NAME' < /home/frappe/temp_nginx.conf > /etc/nginx/conf.d/default.conf
envsubst '$BENCH_PATH,$NODE_PATH' < /home/frappe/temp_supervisor.conf > /home/frappe/supervisor.conf

echo "-> Starting nginx"
nginx

echo "-> Starting supervisor"
/usr/bin/supervisord -c /home/frappe/supervisor.conf
