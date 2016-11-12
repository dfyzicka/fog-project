<?php
/**
 * Task manager class.
 *
 * PHP version 5
 *
 * @category TaskManager
 * @package  FOGProject
 * @author   Tom Elliott <tommygunsster@gmail.com>
 * @license  http://opensource.org/licenses/gpl-3.0 GPLv3
 * @link     https://fogproject.org
 */
/**
 * Task manager class.
 *
 * @category TaskManager
 * @package  FOGProject
 * @author   Tom Elliott <tommygunsster@gmail.com>
 * @license  http://opensource.org/licenses/gpl-3.0 GPLv3
 * @link     https://fogproject.org
 */
class TaskManager extends FOGManagerController
{
    /**
     * Cancels the specified tasks.
     *
     * @param array $taskids The tasks to cancel.
     *
     * @return void
     */
    public function cancel($taskids)
    {
        $cancelled = $this->getCancelledState();
        $notComplete = array_merge(
            (array)$this->getQueuedStates(),
            (array)$this->getProgressState()
        );
        $findWhere = array(
            'id' => (array)$taskids,
            'stateID' => $notComplete
        );
        $hostIDs = self::getSubObjectIDs(
            'Task',
            $findWhere,
            'hostID'
        );
        $this->update(
            $findWhere,
            '',
            array(
                'stateID' => $cancelled
            )
        );
        $findWhere = array(
            'hostID' => $hostIDs,
            'stateID' => $notComplete
        );
        $SnapinJobIDs = self::getSubObjectIDs(
            'SnapinJob',
            $findWhere
        );
        $findWhere = array(
            'stateID' => $notComplete,
            'jobID' => $SnapinJobIDs
        );
        $SnapinTaskIDs = self::getSubObjectIDs(
            'SnapinTask',
            $findWhere
        );
        $findWhere = array(
            'taskID' => $taskids
        );
        $MulticastSessionAssocIDs = self::getSubObjectIDs(
            'MulticastSessionsAssociation',
            $findWhere
        );
        $MulticastSessionIDs = self::getSubObjectIDs(
            'MulticastSessionsAssociation',
            $findWhere,
            'msID'
        );
        $MulticastSessionIDs = self::getSubObjectIDs(
            'MulticastSessions',
            array(
                'stateID' => $notComplete,
                'id' => $MulticastSessionIDs
            )
        );
        if (count($MulticastSessionAssocIDs) > 0) {
            self::getClass('MulticastSessionsAssociationManager')
                ->destroy(array('id' => $MulticastSessionsAssocIDs));
        }
        $StillLeft = self::getClass('MulticastSessionsAssociationManager')
            ->count(array('msID' => $MulticastSessionIDs));
        if (count($SnapinTaskIDs) > 0) {
            self::getClass('SnapinTaskManager')->cancel($SnapinTaskIDs);
        }
        if (count($SnapinJobIDs) > 0) {
            self::getClass('SnapinJobManager')->cancel($SnapinJobIDs);
        }
        if ($StillLeft < 1 && count($MulticastSessionIDs) > 0) {
            self::getClass('MulticastSessionsManager')->cancel($MulticastSessionIDs);
        }
    }
}
